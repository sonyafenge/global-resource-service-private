package options

import (
	"time"
)

// ServerRunOptions runs a kubernetes api server.
type ServerRunOptions struct {
	Address                     string
	SecurePort                  int
	InSecurePort                int
	MaxRequestsInFlight         int
	MaxMutatingRequestsInFlight int
	RequestTimeout              time.Duration
	MinRequestTimeout           int
	JSONPatchMaxCopyBytes       int64
	MaxRequestBodyBytes         int64
}

// NewServerRunOptions creates a new ServerRunOptions object with default parameters
func NewServerRunOptions() *ServerRunOptions {
	s := ServerRunOptions{
		Address:                     "127.0.0.1",
		SecurePort:                  443,
		InSecurePort:                8080,
		MaxRequestsInFlight:         400,
		MaxMutatingRequestsInFlight: 200,
		RequestTimeout:              time.Duration(60) * time.Second,
		MinRequestTimeout:           1800,
		JSONPatchMaxCopyBytes:       int64(100 * 1024 * 1024),
		MaxRequestBodyBytes:         int64(100 * 1024 * 1024),
	}
	return &s
}
