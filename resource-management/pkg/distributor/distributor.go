package distributor

import (
	"log"
	"strconv"
	"time"

	"global-resource-service/resource-management/pkg/types"

	"github.com/google/uuid"
)

type Distributor struct {
	NodesList []types.Node
}

func (d *Distributor) BuildNodeList() {

	if len(d.NodesList) == 0 {
		d.NodesList = make([]types.Node, 2)
	}

	i := 0
	for i < 2 {
		d.NodesList[i] = *types.NewNode(uuid.New().String(), strconv.FormatInt(int64(i), 10), "NodeLabel", types.NewLocation("Shanghai", "Huazhong"))
		i++
	}
	log.Printf("BuildNodeList lenth: %d", len(d.NodesList))
	log.Printf("NodeList: %v", d.NodesList)
}

func (d *Distributor) ListNodeList() []types.Node {
	log.Printf("ListdNodeList lenth: %d", len(d.NodesList))
	log.Printf("ListNodeList: %v", d.NodesList)
	return d.NodesList
}

// the real case, this is running in separated threads in the process event routine
/*func (d *Distributor) RenderNewNodes() {

	i := len(d.NodesList)
	j := 1 + 100
	for i < j {
		newNode := types.NewNode(uuid.New().String(), strconv.FormatInt(int64(i), 10), "NodeLabel", types.NewLocation("Shanghai", "Huazhong"))

		watchChannel <- *newNode

		d.NodesList[i] = *newNode
		i++

		time.Sleep(time.Millisecond * 50)
	}
}
*/

func (d *Distributor) UpdateRequest(req types.ResourceRequest) {

	for _, r := range req.TotalRequest {
		log.Printf("Add new machine for region %s", r.RegionName)
		i := len(d.NodesList)
		j := 1 + 100
		for i < j {
			newNode := types.NewNode(uuid.New().String(), strconv.FormatInt(int64(i), 10), "NodeLabel", types.NewLocation("Shanghai", "Huazhong"))

			//watchChannel <- *newNode

			d.NodesList[i] = *newNode
			i++

			time.Sleep(time.Millisecond * 50)
		}
	}
}
