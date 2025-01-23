FROM vaultwarden/server:latest

RUN apt-get update && apt-get install -y unzip jq curl libsecret-1-dev

RUN export DOWNLOAD_URL="https://vault.bitwarden.com/download/?app=cli&platform=linux" \
    && for i in {1..5}; do curl -sL "$DOWNLOAD_URL" -o bw.zip && break || echo "Download attempt $i failed. Retrying..."; sleep 1; done \
    && if [[ $? -ne 0 ]]; then echo "Error downloading bw.zip after multiple retries." && exit 1 ; fi \
    && unzip -q bw.zip && if [[ $? -ne 0 ]]; then echo "Error unzipping bw.zip" && exit 1 ; fi \
    && mv bw /usr/local/bin \
    && rm bw.zip

ARG DOMAIN

RUN bw config server ${DOMAIN}

ENTRYPOINT ["bw"]

CMD ["/bin/bash"]