package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/gorilla/mux"
)

type APIInstaller struct {
	//group             *APIGroupVersion
	prefix            string // Path prefix where API resources are to be registered.
	minRequestTimeout time.Duration
}

// URL path
const REGIONLESS_RESOURCE_PATH = "/resource"
const REGIONLESS_CLIENT_PATH = "/clients"

var dist Distributor
var watchChannel = make(chan MinNodeRecord)
var clients = make(map[string]Client, 4)

func init() {

	clients = make(map[string]Client, 4)
	clients["test100"] = Client{"test100", ClientInfoType{"testclient"}}

	watchChannel = make(chan MinNodeRecord)

	dist = Distributor{}
	dist.BuildNodeList()
}

func ResourceHandler(resp http.ResponseWriter, req *http.Request) {
	log.Println("handle /resource. URL path: %s", req.URL.Path)

	switch req.Method {
	case http.MethodGet:
		ret, err := json.Marshal(dist.ListNodeList())
		log.Println("http.MethodGet - dist.ListNodeList: %s", dist.ListNodeList())
		if err != nil {
			log.Println("error read get node list. error %v", err)
			resp.WriteHeader(http.StatusInternalServerError)
			return
		}
		resp.Write(ret)
	default:
		resp.WriteHeader(http.StatusMethodNotAllowed)
		return
	}

}

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
	r.HandleFunc("/resource", ResourceHandler).Methods("GET")
	server := &http.Server{
		Handler:      r,
		Addr:         "localhost:8080",
		WriteTimeout: 2 * time.Second,
		ReadTimeout:  2 * time.Second,
	}

	log.Fatal(server.ListenAndServe())
}
