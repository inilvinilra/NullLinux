# Null Linux role tooling in a container.
#
# This image ships the role manager and its manifests only. It deliberately does
# not enable BlackArch or Chaotic-AUR: third-party repositories are opt-in and
# require a verified full key fingerprint, which belongs in a reviewed setup
# step rather than an unattended image build.
FROM archlinux:latest

LABEL org.opencontainers.image.title="Null Linux toolkit"
LABEL org.opencontainers.image.source="https://github.com/inilvinilra/NullLinux"

RUN pacman -Syu --noconfirm base-devel git sudo && pacman -Scc --noconfirm

COPY src/lib/ /usr/share/nulllinux/lib/
COPY iso/airootfs/usr/share/nulllinux/roles/ /usr/share/nulllinux/roles/
COPY src/tools/null-toolkit/null-toolkit /usr/bin/null-toolkit
RUN chmod 0755 /usr/bin/null-toolkit

RUN useradd -m -s /bin/bash null
USER null
WORKDIR /home/null
CMD ["/bin/bash"]
