FROM ruby:2.7-alpine

RUN apk add --no-cache --update build-base \
                                linux-headers \
                                git \
                                postgresql-dev \
                                nodejs \
                                tzdata libcurl curl-dev libxml2 libxml2-dev gcc make \
                                sqlite sqlite-dev sqlite-libs \
                                imagemagick \
                                ffmpeg x264 x265 libvpx libtheora \
                                file

ENV APP_PATH /opt/project

# Different layer for gems installation
WORKDIR $APP_PATH
COPY . $APP_PATH
RUN bundle install --jobs `expr $(cat /proc/cpuinfo | grep -c "cpu cores") - 1` --retry 3
