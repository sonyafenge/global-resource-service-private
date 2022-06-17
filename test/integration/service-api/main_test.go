package service_api

import (
	"testing"

	"global-resource-service/test/integration/framework"
)

func TestMain(m *testing.M) {
	framework.ServerMain(m.Run)
}
