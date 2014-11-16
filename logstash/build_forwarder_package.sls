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
{% set go_version = salt['pillar.get']('logstash-forwarder:build-package:go_version', '1.3.3') %}
{% set go_source_hash = salt['pillar.get']('logstash-forwarder:build-package:go_source_hash', '14068fbe349db34b838853a7878621bbd2b24646') %}

packaging_reqs:
  pkg.installed:
    - pkgs: {{ logstash.forwarder_pkging_deps }}

install_golang:
  archive.extracted:
    - name: /usr/local/
    - source: https://storage.googleapis.com/golang/go{{ go_version }}.linux-amd64.tar.gz
    - source_hash: sha1={{ go_source_hash }}
    - archive_format: tar
    - tar_options: xzv
    - if_missing: /usr/local/go
  file.append:
    - name: /etc/profile
    - text: "export PATH=$PATH:/usr/local/go/bin"

fpm:
  gem.installed:
    - require:
        - pkg: packaging_reqs

forwarder_src:
  git.latest:
    - name: https://github.com/elasticsearch/logstash-forwarder
    - rev: {{ git_rev }}
    - target: /tmp/logstash-forwarder
    - require:
        - pkg: packaging_reqs

compile_forwarder:
  cmd.run:
    - name: go build
    - cwd: /tmp/logstash-forwarder
    - env:
        - PATH: '$PATH:/usr/local/go/bin'
    - require:
        - git: forwarder_src

package_forwarder:
  cmd.run:
    - name: /usr/bin/make {{ package_type }}
    - cwd: /tmp/logstash-forwarder
    - shell: /bin/bash
    - env:
        - PATH: '/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:/usr/local/go/bin'
    - require:
        - cmd: compile_forwarder
        - git: forwarder_src
        - gem: fpm

package_directory:
  file.directory:
    - name: {{ file_root }}/built_packages
    - makedirs: True

move_package:
  cmd.run:
    - name: mv /tmp/logstash-forwarder/{{ package_filename }} {{ file_root }}/built_packages/logstash-forwarder.{{ package_type }}
    - require:
        - cmd: package_forwarder