package main

type GeoInfo struct {
	RegionName string
	DcName     string
	RackId     string
}

type MinNodeRecord struct {
	NodeId   string
	NodeRV   int64
	Location GeoInfo
}

// quota
type ResourceQuota struct {
	TotalMachines int
	// TODO: add map for machine types and special hardware request quotas
}

// client
type Client struct {
	ClientId string

	ClientInfo ClientInfoType
}

type ClientInfoType struct {
	ClientName string
	// TODO: other info if needed
}

// resourceReq
// default to request all region, 10K nodes total, no special hardwares
type ResourceRequest struct {
	TotalRequest []RequestPerRegion
}

// per selected region
type RequestPerRegion struct {
	// Name of the region
	RegionName string

	// Machines requested per host machine type; machine type defined as CPU type etc.
	// flavors
	Machines map[MachineType]int

	// Machines requested per special hardware type, e.g., GPU / FPGA machines
	SpecialHardwareMachines map[string]int
}

// host with different hardware variations, such as CPU categories, ARM x86 etc.
type MachineType string
