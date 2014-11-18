{% from "logstash/map.jinja" import logstash with context %}

{% set logstash_servers = [] %}
{% for id, ip_addrs in salt['mine.get']('roles:logstash', 'network.ip_addrs', expr_form='grain').items() %}
  {% do logstash_servers.append(ip_addrs[0]) %}
{% endfor %}
{% set logstash_port = salt['pillar.get']('beaver:tcp_port', 7777) %}
{% set conf_list = salt['pillar.get']('beaver:extra_configs', []) %}

beaver_deps:
  pkg.installed:
    - pkgs: {{ logstash.beaver_deps }}

install_beaver:
  pip.installed:
    - name: beaver
    - require:
        - pkg: beaver_deps

beaver_config_dirs:
  file.directory:
    - name: /etc/beaver/conf.d
    - makedirs: True

beaver_base_config:
  file.managed:
    - name: /etc/beaver/conf
    - source: salt://logstash/files/beaver.ini
    - template: jinja
    - context:
        logstash_host: {{ logstash_servers[0] }}
        logstash_port: {{ logstash_port }}

{% if grains['os'] == 'Ubuntu' %}
beaver_upstart:
  file.managed:
    - name: /etc/init/beaver.conf
    - source: salt://logstash/files/beaver.upstart
    - require_in:
        - service: beaver_service
{% else %}
beaver_systemd:
  file.managed:
    - name: /etc/systemd/system/beaver.service
    - source: salt://logstash/files/beaver.systemd
    - require_in:
        - service: beaver_service
{% endif %}

{% for config in conf_list %}
{{ config.name }}:
  file.managed:
    - name: /etc/beaver/conf.d/{{ config.name }}.ini
    - source: {{ config.source }}
    {% if config.get('source_hash') %}
    - source_hash: {{ config.source_hash }}
    {% endif %}
    {% if config.get('context') %}
    - context: {{ config.context }}
    {% endif %}
    - watch_in:
        - service: beaver_service
{% endfor %}

beaver_service:
  service.running:
    - name: beaver
    - enable: True
    - require:
        - pip: install_beaver