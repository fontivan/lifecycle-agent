#####################################################################################################
# Build arguments
ARG BUILDER_IMAGE=quay.io/projectquay/golang:1.23
ARG RUNTIME_IMAGE=registry.access.redhat.com/ubi9-minimal:9.4
ARG OPENSHIFT_CLI_IMAGE=registry.redhat.io/openshift4/ose-cli-rhel9:latest

# Build the binaries
FROM ${BUILDER_IMAGE} as builder

# Default Konflux to false
ARG KONFLUX="false"

# Explicitly set the working directory
WORKDIR /opt/app-root

# Bring in the go dependencies before anything else so we can take
# advantage of caching these layers in future builds.
COPY vendor/ vendor/

# Copy the go modules manifests
COPY go.* .

# Copy the required source directories
COPY api api
COPY controllers controllers
COPY lca-cli lca-cli
COPY internal internal
COPY main main
COPY utils utils

# For Konflux, compile with FIPS enabled
# Otherwise compile normally
RUN if [[ "${KONFLUX}" == "true" ]]; then \
        echo "Compiling with fips" && \
        GOEXPERIMENT=strictfipsruntime CGO_ENABLED=1 GOOS=linux GO111MODULE=on go build -mod=vendor -tags strictfipsruntime -o build/manager main/main.go && \
        GOEXPERIMENT=strictfipsruntime CGO_ENABLED=1 GOOS=linux GO111MODULE=on go build -mod=vendor -tags strictfipsruntime -a -o build/lca-cli main/lca-cli/main.go; \
    else \
        echo "Compiling without fips" && \
        CGO_ENABLED=0 GOOS=linux GO111MODULE=on go build -mod=vendor -a -o build/manager main/main.go && \
        CGO_ENABLED=0 GOOS=linux GO111MODULE=on go build -mod=vendor -a -o build/lca-cli main/lca-cli/main.go; \
    fi

#####################################################################################################
# Build the operator image
FROM ${OPENSHIFT_CLI_IMAGE} AS openshift-cli
FROM ${RUNTIME_IMAGE} as runtime-image

# Explicitly set the working directory
WORKDIR /

RUN if [[ ! -f /bin/nsenter ]]; then \
        microdnf -y install util-linux-core && \
        microdnf -y install rsync && \
        microdnf -y install tar && \
        microdnf clean all && \
        rm -rf /var/cache/yum ; \
    fi


COPY --from=builder \
    /opt/app-root/build/manager \
    /opt/app-root/build/lca-cli \
    /usr/local/bin/

COPY lca-cli/installation_configuration_files/ /usr/local/installation_configuration_files/

COPY --from=openshift-cli /usr/bin/oc /usr/bin/oc

COPY must-gather/collection-scripts/ /usr/bin/

ENTRYPOINT ["/usr/local/bin/manager"]
