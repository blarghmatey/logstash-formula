{% from "logstash/map.jinja" import logstash with context %}

{% set git_rev = salt['pillar.get']('logstash-forwarder:git-rev', 'master') %}
{% set os_family = grains['os_family'] %}
{% set file_root = salt['pillar.get']('logstash-forwarder:build-package:file_root', '/srv/salt/') %}
{% if os_family == 'Debian' %}
{% set package_type = 'deb' %}
{% elif os_family == 'RedHat' %}
{% set package_type = 'rpm' %}
{% endif %}
{% set osarch = grains['osarch'] %}
{% set package_version = salt['pillar.get']('lostash-forwarder:build-package:version', '0.3.1') %}
{% set package_filename = 'logstash-forwarder_{0}_{1}.{2}'.format(package_version, osarch, package_type) %}

packaging_reqs:
  pkg.installed:
    - pkgs: {{ logstash.forwarder_pkging_deps }}

fpm:
  gem.installed

forwarder_src:
  git.latest:
    - name: https://github.com/elasticsearch/logstash-forwarder
    - rev: {{ git_rev }}
    - target: /tmp
    - require:
        - pkg: packaging_reqs

compile_forwarder:
  cmd.run:
    - name: go build
    - cwd: /tmp/logstash-forwarder
    - require:
        - git: forwarder_src

package_forwarder:
  cmd.run:
    - name: make {{ package_type }}
    - cwd: /tmp/logstash-forwarder
    - require:
        - cmd: compile_forwarder
        - git: forwarder_src
        - gem: fpm

move_package:
  file.managed:
    - name: {{ file_root }}/built_packages/logstash-forwarder.{{ package_type }}
    - source: /tmp/logstash-forwarder/{{ package_filename }}
    - require:
        - cmd: package_forwarder