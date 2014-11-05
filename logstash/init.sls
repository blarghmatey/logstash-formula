{% from "logstash/map.jinja" import logstash with context %}

{% set os_family = grains['os_family'] %}

setup_pkg_repo:
  pkgrepo.managed:
    - humanname: Logstash
    {% if os_family == 'Debian' %}
    - name: deb http://packages.elasticsearch.org/logstash/1.4/debian stable main
    {% elif os_family == 'RedHat' %}
    - baseurl: http://packages.elasticsearch.org/logstash/1.4/centos
    - gpgcheck: 1
    - enabled: 1
    {% endif %}
    - key_url: http://packages.elasticsearch.org/GPG-KEY-elasticsearch
    - require_in:
        - pkg: logstash_pkg_reqs

logstash_pkg_reqs:
  pkg.installed:
    - pkgs: {{ logstash.pkgs }}

start_logstash:
  service.running:
    - name: logstash
    - enable: True
    - require:
        - pkg: logstash_pkg_reqs