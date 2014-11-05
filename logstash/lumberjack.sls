{% from "logstash/map.jinja" import logstash with context %}

{% set os_family = grains['os_family'] %}

setup_pkg_repo:
  pkgrepo.managed:
    - humanname: Logstash
    {% if os_family == 'Debian' %}
    - name: deb http://packages.elasticsearch.org/logstashforwarder/debian stable main
    {% elif os_family == 'RedHat' %}
    - baseurl: http://packages.elasticsearch.org/logstashforwarder/centos
    - gpgcheck: 1
    - enabled: 1
    {% endif %}
    - key_url: http://packages.elasticsearch.org/GPG-KEY-elasticsearch
    - require_in:
        - pkg: logstash-forwarder

logstash-forwarder:
  pkg.installed

forwarder_service:
  service.running:
    - name: logstash-forwarder
    - enable: True
    - require:
        - pkg: logstash-forwarder