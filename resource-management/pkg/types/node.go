package types

import (
	"fmt"
	"strconv"
)

type Node struct {
	Id              string
	ResourceVersion string
	Label           string
	Loc             *Location
}

func NewNode(id, rv, label string, location *Location) *Node {
	return &Node{
		Id:              id,
		ResourceVersion: rv,
		Label:           label,
		Loc:             location,
	}
}

func (n *Node) Copy() *Node {
	return &Node{
		Id:              n.Id,
		ResourceVersion: n.ResourceVersion,
		Label:           n.Label,
		Loc:             n.Loc,
	}
}

func (n *Node) GetId() string {
	return n.Id
}

func (n *Node) GetLocation() *Location {
	return n.Loc
}

func (n *Node) GetResourceVersion() uint64 {
	rv, err := strconv.ParseUint(n.ResourceVersion, 10, 64)
	if err != nil {
		fmt.Printf("Unable to convert resource version %s to uint64\n", n.ResourceVersion)
		return 0
	}
	return rv
}

type HardwareConfig struct {
	ConfigId string
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
