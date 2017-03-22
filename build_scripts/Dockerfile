FROM ppc64le/ubuntu

RUN apt-get update && apt-get -y install  unzip \
                        xz-utils \
                        curl \
                        bc \
                        git \
			wget \
			locales \
			language-pack-en \
			python python-pip curl \
                        build-essential \
                        golang \
                        cpio \
                        gcc libc6 libc6-dev libssl-dev \
                        kmod \
                        genisoimage \
                        automake \
			libtool \
			make \
			sudo \
                        pkg-config \
                        p7zip-full

# https://www.kernel.org/
ENV KERNEL_VERSION  4.4.16

# Fetch the kernel sources
RUN curl --retry 10 https://www.kernel.org/pub/linux/kernel/v${KERNEL_VERSION%%.*}.x/linux-$KERNEL_VERSION.tar.xz | tar -C / -xJ && \
    mv /linux-$KERNEL_VERSION /linux-kernel

# http://aufs.sourceforge.net/
ENV AUFS_REPO       https://github.com/sfjro/aufs4-standalone
ENV AUFS_BRANCH     aufs4.4
ENV AUFS_COMMIT     45192fd8c7c447090b990953c62760dc18508dd7
# we use AUFS_COMMIT to get stronger repeatability guarantees

# Download AUFS and apply patches and files, then remove it
RUN git clone -b "$AUFS_BRANCH" "$AUFS_REPO" /aufs-standalone && \
    cd /aufs-standalone && \
    git checkout -q "$AUFS_COMMIT" && \
    cd /linux-kernel && \
    cp -r /aufs-standalone/Documentation /linux-kernel && \
    cp -r /aufs-standalone/fs /linux-kernel && \
    cp -r /aufs-standalone/include/uapi/linux/aufs_type.h /linux-kernel/include/uapi/linux/ && \
    set -e && for patch in \
        /aufs-standalone/aufs*-kbuild.patch \
        /aufs-standalone/aufs*-base.patch \
        /aufs-standalone/aufs*-mmap.patch \
        /aufs-standalone/aufs*-standalone.patch \
        /aufs-standalone/aufs*-loopback.patch \
    ; do \
        patch -p1 < "$patch"; \
    done

COPY config/kernel_config /linux-kernel/.config

RUN jobs=$(nproc); \
    cd /linux-kernel && \
    make -j ${jobs} oldconfig && \
    make -j ${jobs} zImage && \
    make -j ${jobs} modules

# The post kernel build process

ENV ROOTFS /rootfs

# Make the ROOTFS
RUN mkdir -p $ROOTFS

# Prepare the build directory (/tmp/iso)
#RUN mkdir -p /tmp/iso/boot
RUN mkdir /isoimage
COPY isoimage/  /isoimage/

RUN mkdir /docker-binaries
COPY docker-binaries/  /docker-binaries/

# Install the kernel modules in $ROOTFS
RUN cd /linux-kernel && \
   make INSTALL_MOD_PATH=$ROOTFS modules_install firmware_install

# Remove useless kernel modules, based on unclejack/debian2docker
RUN cd $ROOTFS/lib/modules && \
    rm -rf ./*/kernel/sound/* && \
    rm -rf ./*/kernel/drivers/gpu/* && \
    rm -rf ./*/kernel/drivers/infiniband/* && \
    rm -rf ./*/kernel/drivers/isdn/* && \
    rm -rf ./*/kernel/drivers/media/* && \
    rm -rf ./*/kernel/drivers/staging/lustre/* && \
    rm -rf ./*/kernel/drivers/staging/comedi/* && \
    rm -rf ./*/kernel/fs/ocfs2/* && \
    rm -rf ./*/kernel/net/bluetooth/* && \
    rm -rf ./*/kernel/net/mac80211/* && \
    rm -rf ./*/kernel/net/wireless/*

# Make sure the kernel headers are installed for aufs-util, and then build it
ENV AUFS_UTIL_REPO    git://git.code.sf.net/p/aufs/aufs-util
ENV AUFS_UTIL_BRANCH  aufs4.1
ENV AUFS_UTIL_COMMIT  12eff17c0de02bd36c89c45a28aa5dc6536ef956
RUN set -ex \
	&& git clone -b "$AUFS_UTIL_BRANCH" "$AUFS_UTIL_REPO" /aufs-util \
	&& git -C /aufs-util checkout --quiet "$AUFS_UTIL_COMMIT" \
	&& make -C /linux-kernel headers_install INSTALL_HDR_PATH=/tmp/kheaders \
	&& export CFLAGS='-I/tmp/kheaders/include' \
	&& export CPPFLAGS="$CFLAGS" LDFLAGS="$CFLAGS" \
	&& make -C /aufs-util \
	&& make -C /aufs-util install DESTDIR="$ROOTFS" \
	&& rm -r /tmp/kheaders

# Prepare the ISO directory with the kernel
RUN cp -v /linux-kernel/arch/powerpc/boot/zImage /isoimage/ppc/ppc64/

#remove kernel source after building
#RUN rm -rf /linux-kernel/

# build rootfs using buildroot
#https://buildroot.org/
ENV BUILDROOT_VERSION  2016.11.1
# Fetch the buildroot sources
RUN curl --retry 10 https://buildroot.org/downloads/buildroot-$BUILDROOT_VERSION.tar.gz | tar -C / -xz && \
    mv /buildroot-$BUILDROOT_VERSION /buildroot

COPY config/buildroot-$BUILDROOT_VERSION.config  /buildroot/.config

RUN jobs=$(nproc); \
    cd /buildroot && \
    make -j ${jobs} && \
    cp -av /buildroot/output/images/rootfs.tar $ROOTFS/


RUN mkdir -p /scripts
COPY scripts/  /scripts/  

#COPY rootfs/rootfs.tar  $ROOTFS/
RUN cd /rootfs && \
        tar -xvf rootfs.tar && \
        rm -rf rootfs.tar && \
	cp /scripts/init /rootfs/ && \
	cp /scripts/S90automount /scripts/S91docker /scripts/docker /rootfs/etc/init.d/ && \
	cp /scripts/autologin /scripts/sethostname /rootfs/usr/bin/ &&  \
        cp /scripts/interfaces /rootfs/etc/network/ && \
	cp /docker-binaries/*    /rootfs/usr/bin/ && \
	chmod 755 /rootfs/etc/sudoers  && \
	rm -f /rootfs/etc/os-release  && \
	rm -f /rootfs/etc/inittab && \
	rm -f /rootfs/bin/login && \
	rm -f /rootfs/etc/resolv.conf && \
	cd /rootfs/bin &&  \
	sudo ln -s busybox login 


#remove unused kernel modules
RUN cd /rootfs/lib/modules/4.4.16/kernel/ && \
	 find . -type f | sort > /root/installed_modules.list && \
	 cp /scripts/kernel_modules.list /root/ && \
	 cd  /root && \
	 sort kernel_modules.list -o kernel_modules.list  && \
	 comm -13 kernel_modules.list installed_modules.list > /rootfs/lib/modules/4.4.16/kernel/rm_modules.list && \
	 cd /rootfs/lib/modules/4.4.16/kernel/ && \
	 xargs -a rm_modules.list rm 

RUN cd /rootfs && \
	cp /scripts/os-release /scripts/inittab /scripts/resolv.conf /rootfs/etc/  && \
	rm -f /rootfs/rootfs.tar && \
	cd /rootfs && \
	sudo find . | cpio -oHnewc | gzip > /isoimage/ppc/ppc64/initramfs.gz

RUN mkdir -p /boot2docker_iso
RUN cd /isoimage/ && \
	mkisofs -R -V "Docker" -sysid PPC -chrp-boot -U  -no-desktop -allow-multidot -volset 4 -volset-size 1 -volset-seqno 1 -hfs-volid 4 -o ../boot2docker_iso/Boot2docker.iso . && \
	ls -lh /rootfs/ && \
	ls -lh  /boot2docker_iso/
    
VOLUME /boot2docker_iso/


#CMD ["/bin/sh"]
CMD ["sh", "-c", "[ -t 1 ] && exec bash || exec cat /boot2docker_iso/Boot2docker.iso"]
