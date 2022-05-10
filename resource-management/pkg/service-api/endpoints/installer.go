package endpoints

import (
	"encoding/json"
	"io/ioutil"
	"log"
	"net/http"

	"global-resource-service/resource-management/pkg/distributor"
	"global-resource-service/resource-management/pkg/types"
)

/*
type APIInstaller struct {
	//group             *APIGroupVersion
	prefix            string // Path prefix where API resources are to be registered.
	minRequestTimeout time.Duration
}
*/

// URL path
const REGIONLESS_RESOURCE_PATH = "/resource"

//const REGIONLESS_CLIENT_PATH = "/clients"

var dist distributor.Distributor

//var watchChannel = make(chan types.Node)

func init() {

	//watchChannel = make(chan types.Node)

	dist = distributor.Distributor{}
	dist.BuildNodeList()
}

func ResourceHandler(resp http.ResponseWriter, req *http.Request) {
	log.Printf("handle /resource. URL path: %s", req.URL.Path)

	switch req.Method {
	case http.MethodGet:
		ret, err := json.Marshal(dist.ListNodeList())
		log.Printf("http.MethodGet - dist.ListNodeList: %v", dist.ListNodeList())
		log.Printf("http.MethodGet - json.Marshal(dist.ListNodeList): %s", ret)
		if err != nil {
			log.Printf("error read get node list. error %v", err)
			resp.WriteHeader(http.StatusInternalServerError)
			return
		}
		resp.Write(ret)
	case http.MethodPost:
		resp.WriteHeader(http.StatusMethodNotAllowed)
		return
	case http.MethodPut:
		obj := types.ResourceRequest{}

		body, err := ioutil.ReadAll(req.Body)
		log.Printf("http.MethodPut - req.Body: %s", req.Body)
		if err != nil {
			log.Printf("error read request body. error %v", err)
			resp.WriteHeader(http.StatusInternalServerError)
			return
		}

		err = json.Unmarshal(body, &obj)
		if err != nil {
			log.Printf("error unmarshal request body. error %v", err)
			resp.WriteHeader(http.StatusInternalServerError)
			return
		}

		dist.UpdateRequest(obj)
	case http.MethodDelete:
		resp.WriteHeader(http.StatusMethodNotAllowed)
		return
	default:
		resp.WriteHeader(http.StatusMethodNotAllowed)
		return
	}

}

/*
func main() {
	fmt.Printf("Starting the API server...")
	// log to custom file
	LOG_FILE := "/tmp/regionless_log"
	// open log file
	logFile, err := os.OpenFile(LOG_FILE, os.O_APPEND|os.O_RDWR|os.O_CREATE, 0644)
	if err != nil {
		log.Panic(err)
	}
	defer logFile.Close()

	// Set log out put and enjoy :)
	log.SetOutput(logFile)

	// optional: log date-time, filename, and line number
	log.SetFlags(log.Lshortfile | log.LstdFlags)

	r := mux.NewRouter()
	r.HandleFunc(REGIONLESS_RESOURCE_PATH, ResourceHandler)
	server := &http.Server{
		Handler:      r,
		Addr:         "localhost:8080",
		WriteTimeout: 2 * time.Second,
		ReadTimeout:  2 * time.Second,
	}

	log.Fatal(server.ListenAndServe())
}

*/
