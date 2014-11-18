{% from "logstash/map.jinja" import logstash with context %}

{% set os_family = grains['os_family'] %}
{% set use_lumberjack = salt['pillar.get']('logstash:use_lumberjack', False) %}
{% set lumberjack_port = salt['pillar.get']('logstash-forwarder:port', 7000) %}
{% set use_beaver = salt['pillar.get']('logstash:use_beaver', True) %}
{% set beaver_port = salt['pillar.get']('beaver:tcp_port', 7777) %}
{% set conf_list = salt['pillar.get']('logstash:extra_configs', []) %}

setup_logstash_pkg_repo:
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

logstash_config:
  file.managed:
    - name: /etc/logstash/conf.d/default.conf
    - source: salt://logstash/files/logstash.conf
    - template: jinja
    - context:
        use_lumberjack: {{ use_lumberjack }}
        lumberjack_port: {{ lumberjack_port }}
        use_syslog: {{ salt['pillar.get']('logstash:syslog_input', True) }}
        elasticsearch_output: {{ salt['pillar.get']('logstash:elasticsearch_output', True) }}
        elasticsearch_http_output: {{ salt['pillar.get']('logstash:elasticsearch_http_output', False) }}
        elasticsearch_http_host: {{ salt['pillar.get']('logstash:elasticsearch_http_host') }}
        elasticsearch_http_port: {{ salt['pillar.get']('logstash:elasticsearch_http_port', 9200) }}
        syslog_port: {{ salt['pillar.get']('logstash:syslog_port', 2000) }}
        use_beaver: {{ use_beaver }}
        beaver_port: {{ beaver_port }}

{% for config in conf_list %}
{{ config.name }}:
  file.managed:
    - name: /etc/logstash/conf.d/{{ config.name }}.conf
    - template: jinja
    - source: {{ config.source }}
    {% if config.get('source_hash') %}
    - source_hash: {{ config.source_hash }}
    {% endif %}
    {% if config.get('context') %}
    context: {{ config.context }}
    {% endif %}
    - watch_in:
        - service: logstash_service
{% endfor %}

{% if use_lumberjack %}
lumberjack_logstash_ssl_key:
  file.managed:
    - name: /etc/logstash-forwarder/ssl/logstash-forwarder.key
    - contents_pillar: logstash-forwarder:ssl_key
    - makedirs: True

lumberjack_logstash_ssl_cert:
  file.managed:
    - name: /etc/logstash-forwarder/ssl/logstash-forwarder.crt
    - contents_pillar: logstash-forwarder:ssl_cert
    - makedirs: True
{% endif %}

logstash_service:
  service.running:
    - name: logstash
    - enable: True
    - require:
        - pkg: logstash_pkg_reqs
    - watch:
        - file: logstash_config
