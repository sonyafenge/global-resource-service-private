package meta

type ObjectMetaAccessor interface {
	GetObjectMeta() Object
}

// ListMetaAccessor retrieves the list interface from an object
type ListMetaAccessor interface {
	GetListMeta() ListInterface
}

// Common lets you work with core metadata from any of the versioned or
// internal API objects. Attempting to set or retrieve a field on an object that does
// not support that field will be a no-op and return a default value.
// TODO: move this, and TypeMeta and ListMeta, to a different package
type Common interface {
	GetResourceVersion() string
	SetResourceVersion(version string)
	GetSelfLink() string
	SetSelfLink(selfLink string)
}

// ListInterface lets you work with list metadata from any of the versioned or
// internal API objects. Attempting to set or retrieve a field on an object that does
// not support that field will be a no-op and return a default value.
// TODO: move this, and TypeMeta and ListMeta, to a different package
type ListInterface interface {
	GetResourceVersion() string
	SetResourceVersion(version string)
	GetSelfLink() string
	SetSelfLink(selfLink string)
	GetContinue() string
	SetContinue(c string)
	GetRemainingItemCount() *int64
	SetRemainingItemCount(c *int64)
}

type NodeInterface interface {
	GetId() string
	GetResourceVersion() string
	GetGeoInfo() NodeGeoInfo
	GetTaints() NodeTaints
	GetSpecialHardwareTypes() NodeSpecialHardWareTypeInfo
	GetAllocatableResource() NodeResource
	GetConditions() byte
	GetReserved() bool
	GetMachineType() NodeMachineType
}

var _ ListInterface = &ListMeta{}

func (meta *ListMeta) GetResourceVersion() string        { return meta.ResourceVersion }
func (meta *ListMeta) SetResourceVersion(version string) { meta.ResourceVersion = version }
func (meta *ListMeta) GetSelfLink() string               { return meta.SelfLink }
func (meta *ListMeta) SetSelfLink(selfLink string)       { meta.SelfLink = selfLink }
func (meta *ListMeta) GetContinue() string               { return meta.Continue }
func (meta *ListMeta) SetContinue(c string)              { meta.Continue = c }
func (meta *ListMeta) GetRemainingItemCount() *int64     { return meta.RemainingItemCount }
func (meta *ListMeta) SetRemainingItemCount(c *int64)    { meta.RemainingItemCount = c }

func (obj *ListMeta) GetListMeta() ListInterface { return obj }

func (node *LogicalNode) GetNodeMeta() NodeInterface { return node }

func (node *LogicalNode) GetId() string              { return node.Id }
func (node *LogicalNode) GetResourceVersion() string { return node.ResourceVersion }
func (node *LogicalNode) GetGeoInfo() NodeGeoInfo    { return node.NodeGeoInfo }
func (node *LogicalNode) GetTaints() NodeTaints      { return node.NodeTaints }
func (node *LogicalNode) GetSpecialHardwareTypes() NodeSpecialHardWareTypeInfo {
	return node.NodeSpecialHardWareTypeInfo
}
func (node *LogicalNode) GetAllocatableResource() NodeResource { return node.NodeResource }
func (node *LogicalNode) GetConditions() byte                  { return node.Conditions }
func (node *LogicalNode) GetReserved() bool                    { return node.Reserved }
func (node *LogicalNode) GetMachineType() NodeMachineType      { return node.NodeMachineType }
