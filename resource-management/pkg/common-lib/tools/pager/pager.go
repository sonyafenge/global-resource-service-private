package pager

import (
	"context"
	"fmt"

	"k8s.io/apimachinery/pkg/api/errors"
	"k8s.io/apimachinery/pkg/api/meta"
	metainternalversion "k8s.io/apimachinery/pkg/apis/meta/internalversion"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	utilruntime "k8s.io/apimachinery/pkg/util/runtime"
)

const defaultPageSize = 500
const defaultPageBufferSize = 10

// ListOptions is the query options to a standard REST list call.
type ListOptions struct {
	TypeMeta `json:",inline"`

	// A selector to restrict the list of returned objects by their labels.
	// Defaults to everything.
	// +optional
	LabelSelector string `json:"labelSelector,omitempty" protobuf:"bytes,1,opt,name=labelSelector"`
	// A selector to restrict the list of returned objects by their fields.
	// Defaults to everything.
	// +optional
	FieldSelector string `json:"fieldSelector,omitempty" protobuf:"bytes,2,opt,name=fieldSelector"`

	// +k8s:deprecated=includeUninitialized,protobuf=6

	// Watch for changes to the described resources and return them as a stream of
	// add, update, and remove notifications. Specify resourceVersion.
	// +optional
	Watch bool `json:"watch,omitempty" protobuf:"varint,3,opt,name=watch"`
	// allowWatchBookmarks requests watch events with type "BOOKMARK".
	// Servers that do not implement bookmarks may ignore this flag and
	// bookmarks are sent at the server's discretion. Clients should not
	// assume bookmarks are returned at any specific interval, nor may they
	// assume the server will send any BOOKMARK event during a session.
	// If this is not a watch, this field is ignored.
	// If the feature gate WatchBookmarks is not enabled in apiserver,
	// this field is ignored.
	// +optional
	AllowWatchBookmarks bool `json:"allowWatchBookmarks,omitempty" protobuf:"varint,9,opt,name=allowWatchBookmarks"`

	// When specified with a watch call, shows changes that occur after that particular version of a resource.
	// Defaults to changes from the beginning of history.
	// When specified for list:
	// - if unset, then the result is returned from remote storage based on quorum-read flag;
	// - if it's 0, then we simply return what we currently have in cache, no guarantee;
	// - if set to non zero, then the result is at least as fresh as given rv.
	// +optional
	ResourceVersion string `json:"resourceVersion,omitempty" protobuf:"bytes,4,opt,name=resourceVersion"`
	// Timeout for the list/watch call.
	// This limits the duration of the call, regardless of any activity or inactivity.
	// +optional
	TimeoutSeconds *int64 `json:"timeoutSeconds,omitempty" protobuf:"varint,5,opt,name=timeoutSeconds"`

	// limit is a maximum number of responses to return for a list call. If more items exist, the
	// server will set the `continue` field on the list metadata to a value that can be used with the
	// same initial query to retrieve the next set of results. Setting a limit may return fewer than
	// the requested amount of items (up to zero items) in the event all requested objects are
	// filtered out and clients should only use the presence of the continue field to determine whether
	// more results are available. Servers may choose not to support the limit argument and will return
	// all of the available results. If limit is specified and the continue field is empty, clients may
	// assume that no more results are available. This field is not supported if watch is true.
	//
	// The server guarantees that the objects returned when using continue will be identical to issuing
	// a single list call without a limit - that is, no objects created, modified, or deleted after the
	// first request is issued will be included in any subsequent continued requests. This is sometimes
	// referred to as a consistent snapshot, and ensures that a client that is using limit to receive
	// smaller chunks of a very large result can ensure they see all possible objects. If objects are
	// updated during a chunked list the version of the object that was present at the time the first list
	// result was calculated is returned.
	Limit int64 `json:"limit,omitempty" protobuf:"varint,7,opt,name=limit"`
	// The continue option should be set when retrieving more results from the server. Since this value is
	// server defined, clients may only use the continue value from a previous query result with identical
	// query parameters (except for the value of continue) and the server may reject a continue value it
	// does not recognize. If the specified continue value is no longer valid whether due to expiration
	// (generally five to fifteen minutes) or a configuration change on the server, the server will
	// respond with a 410 ResourceExpired error together with a continue token. If the client needs a
	// consistent list, it must restart their list without the continue field. Otherwise, the client may
	// send another list request with the token received with the 410 error, the server will respond with
	// a list starting from the next key, but from the latest snapshot, which is inconsistent from the
	// previous list results - objects that are created, modified, or deleted after the first list request
	// will be included in the response, as long as their keys are after the "next key".
	//
	// This field is not supported when watch is true. Clients may start a watch from the last
	// resourceVersion value returned by the server and not miss any modifications.
	Continue string `json:"continue,omitempty" protobuf:"bytes,8,opt,name=continue"`
}

// ListPageFunc returns a list object for the given list options.
type ListPageFunc func(ctx context.Context, opts ListOptions) (runtime.Object, error)

// SimplePageFunc adapts a context-less list function into one that accepts a context.
func SimplePageFunc(fn func(opts ListOptions) (runtime.Object, error)) ListPageFunc {
	return func(ctx context.Context, opts ListOptions) (runtime.Object, error) {
		return fn(opts)
	}
}

// ListPager assists client code in breaking large list queries into multiple
// smaller chunks of PageSize or smaller. PageFn is expected to accept a
// metav1.ListOptions that supports paging and return a list. The pager does
// not alter the field or label selectors on the initial options list.
type ListPager struct {
	PageSize int64
	PageFn   ListPageFunc

	FullListIfExpired bool

	// Number of pages to buffer
	PageBufferSize int32
}

// New creates a new pager from the provided pager function using the default
// options. It will fall back to a full list if an expiration error is encountered
// as a last resort.
func New(fn ListPageFunc) *ListPager {
	return &ListPager{
		PageSize:          defaultPageSize,
		PageFn:            fn,
		FullListIfExpired: true,
		PageBufferSize:    defaultPageBufferSize,
	}
}

// List returns a single list object, but attempts to retrieve smaller chunks from the
// server to reduce the impact on the server. If the chunk attempt fails, it will load
// the full list instead. The Limit field on options, if unset, will default to the page size.
func (p *ListPager) List(ctx context.Context, options ListOptions) (runtime.Object, bool, error) {
	if options.Limit == 0 {
		options.Limit = p.PageSize
	}
	requestedResourceVersion := options.ResourceVersion
	var list *metainternalversion.List
	paginatedResult := false

	for {
		select {
		case <-ctx.Done():
			return nil, paginatedResult, ctx.Err()
		default:
		}

		obj, err := p.PageFn(ctx, options)
		if err != nil {
			// Only fallback to full list if an "Expired" errors is returned, FullListIfExpired is true, and
			// the "Expired" error occurred in page 2 or later (since full list is intended to prevent a pager.List from
			// failing when the resource versions is established by the first page request falls out of the compaction
			// during the subsequent list requests).
			if !errors.IsResourceExpired(err) || !p.FullListIfExpired || options.Continue == "" {
				return nil, paginatedResult, err
			}
			// the list expired while we were processing, fall back to a full list at
			// the requested ResourceVersion.
			options.Limit = 0
			options.Continue = ""
			options.ResourceVersion = requestedResourceVersion
			result, err := p.PageFn(ctx, options)
			return result, paginatedResult, err
		}
		m, err := meta.ListAccessor(obj)
		if err != nil {
			return nil, paginatedResult, fmt.Errorf("returned object must be a list: %v", err)
		}

		// exit early and return the object we got if we haven't processed any pages
		if len(m.GetContinue()) == 0 && list == nil {
			return obj, paginatedResult, nil
		}

		// initialize the list and fill its contents
		if list == nil {
			list = &metainternalversion.List{Items: make([]runtime.Object, 0, options.Limit+1)}
			list.ResourceVersion = m.GetResourceVersion()
			list.SelfLink = m.GetSelfLink()
		}
		if err := meta.EachListItem(obj, func(obj runtime.Object) error {
			list.Items = append(list.Items, obj)
			return nil
		}); err != nil {
			return nil, paginatedResult, err
		}

		// if we have no more items, return the list
		if len(m.GetContinue()) == 0 {
			return list, paginatedResult, nil
		}

		// set the next loop up
		options.Continue = m.GetContinue()
		// Clear the ResourceVersion on the subsequent List calls to avoid the
		// `specifying resource version is not allowed when using continue` error.
		// See https://github.com/kubernetes/kubernetes/issues/85221#issuecomment-553748143.
		options.ResourceVersion = ""
		// At this point, result is already paginated.
		paginatedResult = true
	}
}

// EachListItem fetches runtime.Object items using this ListPager and invokes fn on each item. If
// fn returns an error, processing stops and that error is returned. If fn does not return an error,
// any error encountered while retrieving the list from the server is returned. If the context
// cancels or times out, the context error is returned. Since the list is retrieved in paginated
// chunks, an "Expired" error (metav1.StatusReasonExpired) may be returned if the pagination list
// requests exceed the expiration limit of the apiserver being called.
//
// Items are retrieved in chunks from the server to reduce the impact on the server with up to
// ListPager.PageBufferSize chunks buffered concurrently in the background.
func (p *ListPager) EachListItem(ctx context.Context, options metav1.ListOptions, fn func(obj runtime.Object) error) error {
	return p.eachListChunkBuffered(ctx, options, func(obj runtime.Object) error {
		return meta.EachListItem(obj, fn)
	})
}

// eachListChunkBuffered fetches runtimeObject list chunks using this ListPager and invokes fn on
// each list chunk.  If fn returns an error, processing stops and that error is returned. If fn does
// not return an error, any error encountered while retrieving the list from the server is
// returned. If the context cancels or times out, the context error is returned. Since the list is
// retrieved in paginated chunks, an "Expired" error (metav1.StatusReasonExpired) may be returned if
// the pagination list requests exceed the expiration limit of the apiserver being called.
//
// Up to ListPager.PageBufferSize chunks are buffered concurrently in the background.
func (p *ListPager) eachListChunkBuffered(ctx context.Context, options metav1.ListOptions, fn func(obj runtime.Object) error) error {
	if p.PageBufferSize < 0 {
		return fmt.Errorf("ListPager.PageBufferSize must be >= 0, got %d", p.PageBufferSize)
	}

	// Ensure background goroutine is stopped if this call exits before all list items are
	// processed. Cancelation error from this deferred cancel call is never returned to caller;
	// either the list result has already been sent to bgResultC or the fn error is returned and
	// the cancelation error is discarded.
	ctx, cancel := context.WithCancel(ctx)
	defer cancel()

	chunkC := make(chan runtime.Object, p.PageBufferSize)
	bgResultC := make(chan error, 1)
	go func() {
		defer utilruntime.HandleCrash()

		var err error
		defer func() {
			close(chunkC)
			bgResultC <- err
		}()
		err = p.eachListChunk(ctx, options, func(chunk runtime.Object) error {
			select {
			case chunkC <- chunk: // buffer the chunk, this can block
			case <-ctx.Done():
				return ctx.Err()
			}
			return nil
		})
	}()

	for o := range chunkC {
		err := fn(o)
		if err != nil {
			return err // any fn error should be returned immediately
		}
	}
	// promote the results of our background goroutine to the foreground
	return <-bgResultC
}

// eachListChunk fetches runtimeObject list chunks using this ListPager and invokes fn on each list
// chunk. If fn returns an error, processing stops and that error is returned. If fn does not return
// an error, any error encountered while retrieving the list from the server is returned. If the
// context cancels or times out, the context error is returned. Since the list is retrieved in
// paginated chunks, an "Expired" error (metav1.StatusReasonExpired) may be returned if the
// pagination list requests exceed the expiration limit of the apiserver being called.
func (p *ListPager) eachListChunk(ctx context.Context, options metav1.ListOptions, fn func(obj runtime.Object) error) error {
	if options.Limit == 0 {
		options.Limit = p.PageSize
	}
	for {
		select {
		case <-ctx.Done():
			return ctx.Err()
		default:
		}

		obj, err := p.PageFn(ctx, options)
		if err != nil {
			return err
		}
		m, err := meta.ListAccessor(obj)
		if err != nil {
			return fmt.Errorf("returned object must be a list: %v", err)
		}
		if err := fn(obj); err != nil {
			return err
		}
		// if we have no more items, return.
		if len(m.GetContinue()) == 0 {
			return nil
		}
		// set the next loop up
		options.Continue = m.GetContinue()
	}
}
