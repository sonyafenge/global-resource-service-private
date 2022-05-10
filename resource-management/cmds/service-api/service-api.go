package main

import (
	"fmt"
	"os"

	"global-resource-service/resource-management/cmds/service-api/app"
)

func main() {

	if err := app.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		os.Exit(1)
	}
	//fmt.Printf("Starting the API server...")
	// log to custom file
	//LOG_FILE := "/tmp/service-api.log"
	// open log file
	//logFile, err := os.OpenFile(LOG_FILE, os.O_APPEND|os.O_RDWR|os.O_CREATE, 0644)
	//if err != nil {
	//	log.Panic(err)
	//}
	//defer logFile.Close()

	// Set log out put and enjoy :)
	//log.SetOutput(logFile)

	// optional: log date-time, filename, and line number
	//log.SetFlags(log.Lshortfile | log.LstdFlags)

	/*
		r := mux.NewRouter()
		r.HandleFunc(endpoints.REGIONLESS_RESOURCE_PATH, endpoints.ResourceHandler)
		server := &http.Server{
			Handler:      r,
			Addr:         "localhost:8080",
			WriteTimeout: 2 * time.Second,
			ReadTimeout:  2 * time.Second,
		}

		log.Fatal(server.ListenAndServe())
	*/

}
