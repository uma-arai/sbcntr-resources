# cf. https://gallery.ecr.aws/aws-observability/aws-for-fluent-bit ←FluentBitのバージョンが古いため
#  アップストリームのイメージを利用する
FROM fluent/fluent-bit:4.0.1

COPY fluent-bit-custom.yaml /fluent-bit/etc/fluent-bit-custom.yaml

CMD ["/fluent-bit/bin/fluent-bit", "-c", "/fluent-bit/etc/fluent-bit-custom.yaml"]