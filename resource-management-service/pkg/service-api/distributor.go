package main

import (
	"log"
	"time"

	"github.com/google/uuid"
)

type Distributor struct {
	nodes []MinNodeRecord
}

func (d *Distributor) BuildNodeList() {

	if len(d.nodes) == 0 {
		d.nodes = make([]MinNodeRecord, 1000)
	}

	i := 0
	for i < 1000 {
		d.nodes[i] = MinNodeRecord{uuid.New().String(), int64(i), GeoInfo{"foo", "foo", "foo"}}
		i++
	}
	log.Println("BuildNodeList lenth: %d", len(d.nodes))
	log.Println("NodeList: %s", d.nodes)
}

func (d *Distributor) ListNodeList() []MinNodeRecord {
	log.Println("ListdNodeList lenth: %d", len(d.nodes))
	log.Println("ListNodeList: %s", d.nodes)
	return d.nodes
}

// the real case, this is running in separated threads in the process event routine
func (d *Distributor) RenderNewNodes() {

	i := len(d.nodes)
	j := 1 + 100
	for i < j {
		newNode := MinNodeRecord{uuid.New().String(), int64(i), GeoInfo{"foo", "foo", "foo"}}

		watchChannel <- newNode

		d.nodes[i] = newNode
		i++

		time.Sleep(time.Millisecond * 50)
	}
}

func (d *Distributor) UpdateRequest(req ResourceRequest) {

	for _, r := range req.TotalRequest {
		log.Println("Add new machine for region %s", r.RegionName)
		i := len(d.nodes)
		j := 1 + 100
		for i < j {
			newNode := MinNodeRecord{uuid.New().String(), int64(i), GeoInfo{"foo", "foo", "foo"}}

			watchChannel <- newNode

			d.nodes[i] = newNode
			i++

			time.Sleep(time.Millisecond * 50)
		}
	}
}
