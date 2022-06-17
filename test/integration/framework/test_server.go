package framework

import (
	"os"
	"strings"

	"global-resource-service/resource-management/cmds/service-api/app"
	"k8s.io/klog/v2"
)

// StartTestServer runs a kube-apiserver, optionally calling out to the setup.ModifyServerRunOptions and setup.ModifyServerConfig functions
func startTestServer(appConfig *app.Config) error {
	if err := app.Run(appConfig); err != nil {
		return err
	}

	return nil
}

func ServerMain(tests func() int) {
	// get the commandline arguments
	appConfig := &app.Config{}
	appConfig.MasterIp = "localhost"
	appConfig.MasterPort = "8080"
	urls := "https://localhost:8080/resources/12345"
	appConfig.ResourceUrls = strings.Split(urls, ",")

	err := startTestServer(appConfig)
	if err != nil {
		klog.Fatalf("cannot run integration tests: unable to start service-api: %v", err)
	}
	result := tests()
	os.Exit(result)
}
