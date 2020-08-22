################################################################
# The 19.06 release is the latest NGC release based on Xenial, required
# for Mupen64plus building. Might work with newer OS versions too.
FROM 1.6.0-cuda10.1-cudnn7-runtime AS base


# Setup environment variables in a single layer
ENV \
    # Prevent dpkg from prompting for user input during package setup
    DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
    # mupen64plus will be installed in /usr/games; add to the $PATH
    PATH=$PATH:/usr/games \
    # Set default DISPLAY
    DISPLAY=:0


################################################################
FROM base AS buildstuff

RUN apt-get update && \
    apt-get install -y \
        build-essential dpkg-dev libwebkitgtk-dev libjpeg-dev libtiff-dev libgtk2.0-dev \
        libsdl1.2-dev libgstreamer-plugins-base0.10-dev libnotify-dev freeglut3 freeglut3-dev \
        libjson-c2 libjson-c-dev \
        git

# clone, build, and install the input bot
# (explicitly specifying commit hash to attempt to guarantee behavior within this container)
WORKDIR /src/mupen64plus-src
RUN git clone https://github.com/mupen64plus/mupen64plus-core && \
        cd mupen64plus-core && \
        git reset --hard 12d136dd9a54e8b895026a104db7c076609d11ff && \
    cd .. && \
    git clone https://github.com/kevinhughes27/mupen64plus-input-bot && \
        cd mupen64plus-input-bot && \
        git reset --hard 0b5155b7aa6f9fd3dbbf01b2d2439b5b1acb884f && \
    make all && \
    make install


################################################################
FROM base


# Update package cache and install dependencies
RUN apt-get update && \
    apt-get install -y \
        libjson-c2 \
        wget \
        xvfb libxv1 x11vnc \
        imagemagick \
        mupen64plus \
        nano \
        ffmpeg

# Upgrade pip
RUN pip install --upgrade pip 

# Install VirtualGL (provides vglrun to allow us to run the emulator in XVFB)
# (Check for new releases here: https://github.com/VirtualGL/virtualgl/releases)
ENV VIRTUALGL_VERSION=2.5.2
RUN wget "https://sourceforge.net/projects/virtualgl/files/${VIRTUALGL_VERSION}/virtualgl_${VIRTUALGL_VERSION}_amd64.deb" && \
    apt install ./virtualgl_${VIRTUALGL_VERSION}_amd64.deb && \
    rm virtualgl_${VIRTUALGL_VERSION}_amd64.deb

# Install dependencies (here for caching)
RUN pip install \
    gym==0.7.4 \
    numpy==1.16.2 \
    PyYAML==5.1 \
    termcolor==1.1.0 \
    mss==4.0.2 \
    opencv-python==4.1.0.25

# Copy compiled input plugin from buildstuff layer
COPY --from=buildstuff /usr/local/lib/mupen64plus/mupen64plus-input-bot.so /usr/local/lib/mupen64plus/

# Copy the gym environment (current directory)
COPY . /src/gym-mupen64plus
# Copy the Super Smash Bros. save file to the mupen64plus save directory
# mupen64plus expects a specific filename, hence the awkward syntax and name
COPY [ "./gym_mupen64plus/envs/Smash/smash.sra", "/root/.local/share/mupen64plus/save/Super Smash Bros. (U) [!].sra" ]

# Install requirements & this package
WORKDIR /src/gym-mupen64plus
RUN pip install -e .

# Declare ROMs as a volume for mounting a host path outside the container
VOLUME /src/gym-mupen64plus/gym_mupen64plus/ROMs/

WORKDIR /src

# Expose the default VNC port for connecting with a client/viewer outside the container
EXPOSE 5900
