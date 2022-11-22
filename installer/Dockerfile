FROM ubuntu:jammy AS builder
RUN apt-get update && apt-get install -y wget

RUN wget -O /tmp/kubectl https://dl.k8s.io/release/v1.25.3/bin/linux/amd64/kubectl && chmod +x /tmp/kubectl
RUN wget -O /tmp/ytt https://github.com/vmware-tanzu/carvel-ytt/releases/download/v0.44.0/ytt-linux-amd64 && chmod +x /tmp/ytt
RUN wget -O /tmp/kbld https://github.com/vmware-tanzu/carvel-kbld/releases/download/v0.36.0/kbld-linux-amd64 && chmod +x /tmp/kbld
RUN wget -O /tmp/imgpkg https://github.com/vmware-tanzu/carvel-imgpkg/releases/download/v0.34.0/imgpkg-linux-amd64 && chmod +x /tmp/imgpkg
RUN wget -O /tmp/kapp https://github.com/vmware-tanzu/carvel-kapp/releases/download/v0.54.0/kapp-linux-amd64 && chmod +x /tmp/kapp
RUN wget -O /tmp/yq https://github.com/mikefarah/yq/releases/download/v4.30.4/yq_linux_amd64 && chmod +x /tmp/yq

FROM ubuntu:jammy
RUN apt-get update && apt-get install -y ca-certificates && update-ca-certificates && apt-get clean && /bin/rm -rf /var/lib/apt/lists/*

RUN groupadd --gid 1000 tap-installer && useradd -g 1000 -u 1000 -m tap-installer

COPY --from=builder /tmp/kubectl /usr/local/bin/kubectl
COPY --from=builder /tmp/ytt /usr/local/bin/ytt
COPY --from=builder /tmp/kbld /usr/local/bin/kbld
COPY --from=builder /tmp/imgpkg /usr/local/bin/imgpkg
COPY --from=builder /tmp/kapp /usr/local/bin/kapp
COPY --from=builder /tmp/yq /usr/local/bin/yq

ADD vendor /home/tap-installer/vendor
COPY entrypoint.sh /home/tap-installer/entrypoint.sh
ADD overlays /home/tap-installer/overlays
ADD jobs /home/tap-installer/jobs

RUN chown -R tap-installer:tap-installer /home/tap-installer
RUN find /home/tap-installer -name "*.sh" | xargs chmod +x
USER tap-installer
WORKDIR /home/tap-installer

CMD ["/bin/bash", "-c", "/home/tap-installer/entrypoint.sh"]
