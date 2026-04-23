FROM archlinux:latest

LABEL maintainer="Null Linux Project <https://github.com/xredjhon/NullLinux>"
LABEL description="Null Linux base image with BlackArch and Chaotic-AUR repos"

RUN pacman -Syu --noconfirm && \
    pacman -S --noconfirm \
      base-devel git curl wget sudo nano vim zsh \
      openssh nmap python python-pip && \
    curl -sL https://blackarch.org/strap.sh | bash && \
    pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com && \
    pacman-key --lsign-key 3056513887B78AEB && \
    pacman -U --noconfirm \
      'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' \
      'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst' && \
    echo -e '\n[blackarch]\nInclude = /etc/pacman.d/blackarch-mirrorlist\n' >> /etc/pacman.conf && \
    echo -e '\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist\n' >> /etc/pacman.conf && \
    pacman -Sy --noconfirm && \
    pacman -Scc --noconfirm

RUN useradd -m -s /bin/zsh null && \
    echo 'null ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/null && \
    chmod 0440 /etc/sudoers.d/null

COPY src/tools/null-toolkit/null-toolkit /usr/bin/null-toolkit
COPY config/roles/ /etc/nulllinux/roles.d/
RUN chmod +x /usr/bin/null-toolkit

USER null
WORKDIR /home/null

CMD ["/bin/zsh"]
