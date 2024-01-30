package reboot

import (
	"testing"

	"github.com/go-logr/logr"
	"github.com/openshift-kni/lifecycle-agent/api/v1alpha1"
	"github.com/openshift-kni/lifecycle-agent/internal/ostreeclient"
	"github.com/openshift-kni/lifecycle-agent/lca-cli/ops"
	rpmostreeclient "github.com/openshift-kni/lifecycle-agent/lca-cli/ostreeclient"
	"go.uber.org/mock/gomock"
)

func TestIsOrigStaterootBooted(t *testing.T) {

	var (
		mockController      = gomock.NewController(t)
		mockRpmostreeclient = rpmostreeclient.NewMockIClient(mockController)
		mockOstreeclient    = ostreeclient.NewMockIClient(mockController)
		mockExec            = ops.NewMockExecute(mockController)
	)

	defer func() {
		mockController.Finish()
	}()

	type args struct {
		ibu          *v1alpha1.ImageBasedUpgrade
		r            rpmostreeclient.IClient
		ostreeClient ostreeclient.IClient
		executor     ops.Execute
		log          logr.Logger
	}
	tests := []struct {
		name             string
		args             args
		currentStateRoot string
		want             bool
		wantErr          bool
	}{
		{
			name: "in post pivot when desired stateroot is the same",
			args: args{
				ibu: &v1alpha1.ImageBasedUpgrade{Spec: v1alpha1.ImageBasedUpgradeSpec{SeedImageRef: v1alpha1.SeedImageRef{
					Version: "4.14",
				}}},
				r:            mockRpmostreeclient,
				ostreeClient: mockOstreeclient,
				executor:     mockExec,
			},
			currentStateRoot: "rhcos_4.14",
			want:             false,
			wantErr:          false,
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			rebootClient := NewRebootClient(&tt.args.log, tt.args.executor, tt.args.r, tt.args.ostreeClient)
			mockRpmostreeclient.EXPECT().GetCurrentStaterootName().Return(tt.currentStateRoot, nil).Times(1)
			got, err := rebootClient.IsOrigStaterootBooted(tt.args.ibu)
			if (err != nil) != tt.wantErr {
				t.Errorf("IsOrigStaterootBooted() error = %v, wantErr %v", err, tt.wantErr)
				return
			}
			if got != tt.want {
				t.Errorf("IsOrigStaterootBooted() got = %v, want %v", got, tt.want)
			}
		})
	}
}
