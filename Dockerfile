# EteSync Server - LibreTurks Version
FROM python:3.9-slim

###################### ARGUMENTS #######################
ARG ETESYNC_VERSION
ARG etesyncdav_url="https://github.com/etesync/etesync-dav/releases/latest/download/dist-ubuntu-latest.zip"
########################################################

###################### ENVIRONMENTS ####################
ENV PIP_DISABLE_PIP_VERSION_CHECK=1
ENV PIP_NO_CACHE_DIR=1
ENV ETESYNC_SERVER_HOSTS="0.0.0.0:37358,[::]:37358"
########################################################

###################### PACKAGES ########################
RUN set -ex ;\
    apt-get update && apt-get install -y \
    libpq-dev \
    unzip \
    postgresql-client \
    build-essential \
    wget \
    libc-dev \
    libffi-dev \
    python3-pip \
    python3-venv \
    supervisor && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
########################################################

###################### PYTHON VENV #####################
RUN python3 -m venv /app/venv
ENV PATH="/app/venv/bin:$PATH"
########################################################

###################### PYTHON DEPENDENCIES #############
COPY requirements.txt /app/requirements.txt
RUN pip install -U pip && \
    pip install --no-cache-dir --progress-bar off -r /app/requirements.txt
########################################################

###################### CLEANUP #########################
RUN apt-get remove --purge -y \
    build-essential \
    libc-dev \
    libffi-dev && \
    apt-get autoremove -y && \
    rm -rf /root/.cache
########################################################

###################### APP SETUP #######################
COPY . /app

RUN set -ex ;\
    mkdir -p /data/static /data/media ;\
    cd /app ;\
    mkdir -p /etc/etebase-server ;\
    cp docker/etebase-server.ini /etc/etebase-server ;\
    sed -e '/ETEBASE_CREATE_USER_FUNC/ s/^#*/#/' -i /app/etebase_server/settings.py ;\
    chmod +x docker/entrypoint.sh
########################################################

RUN set -ex ;\
    cd /app ;\
    python manage.py migrate ;\
    python manage.py collectstatic --noinput

###################### ETESYNC DAV ####################
RUN wget "$etesyncdav_url" -O /app/etesync-dav.zip && \
    cd /app && \
    unzip etesync-dav.zip -d /app && \
    chmod +x /app/linux-amd64-etesync-dav
########################################################

###################### SUPERVISOR ######################
RUN mkdir -p /var/log/supervisor
COPY src/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
########################################################

ENV ETESYNC_VERSION=${ETESYNC_VERSION}
VOLUME /data
EXPOSE 3735 37358

CMD ["/usr/bin/supervisord", "-n"]
