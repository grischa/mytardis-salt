{% if grains['os_family'] == 'Debian' %}
rabbitmq-repo:
  pkgrepo.managed:
    - name: "deb http://www.rabbitmq.com/debian/ testing main"
    - key_url: "http://www.rabbitmq.com/rabbitmq-signing-key-public.asc"
    - require_in:
      - pkg: rabbitmq-server
{% endif %}

rabbitmq-server:
  pkg:
    - installed
{% if grains['os_family'] == "RedHat" %}
    - sources:
      - rabbitmq-server: "http://www.rabbitmq.com/releases/rabbitmq-server/v3.2.3/rabbitmq-server-3.2.3-1.noarch.rpm"
{% endif %}
  service.running:
    - require:
      - pkg: rabbitmq-server

{{ pillar['rabbitmq-user'] }}:
  rabbitmq_user.present:
    - password: {{ pillar['rabbitmq-pw'] }}
    - force: true
    - permissions:
      - '/':
        - '.*'
        - '.*'
        - '.*'
    - vhost: {{ pillar['rabbitmq-vhost'] }}
    - runas: root
    - require:
      - file: /etc/rabbitmq/rabbitmq.config

{{ pillar['rabbitmq-vhost'] }}:
  rabbitmq_vhost.present:
    - user: {{ pillar['rabbitmq-user'] }}
    - runas: root
    - require:
      - rabbitmq_user: {{ pillar['rabbitmq-user'] }}

{% if pillar['rabbitmq-ssl'] %}
# create certificates
{% set rabbitmq_ca_name = salt['pillar.get']('rabbitmq-ca-name', 'rabbitmq-ca') %}
{% set cert_path = '/etc/pki/'~rabbitmq_ca_name~'/'~rabbitmq_ca_name~'_ca_cert' %}
rabbitmq-create-ca:
  module.run:
    - name: tls.create_ca
    - ca_name: '{{ rabbitmq_ca_name }}'
    - CN: ca-{{ grains['fqdn'] }}
    - C: 'AU'
    - ST: 'Victoria'
    - L: 'Melbourne'
    - O: 'MyTardis'
    - emailAddress: '{{ salt['pillar.get']('admin_email_address', 'admin@localhost') }}'

rabbitmq-create-csr:
  module.run:
    - name: tls.create_csr
    - ca_name: '{{rabbitmq_ca_name}}'
    - CN: {{ grains['fqdn'] }}
    - C: 'AU'
    - ST: 'Victoria'
    - L: 'Melbourne'
    - O: 'MyTardis'
    - emailAddress: '{{ salt['pillar.get']('admin_email_address', 'admin@localhost') }}'
    - require:
        - module: rabbitmq-create-ca

rabbitmq-create-ca-signed-cert:
  module.run:
    - name: tls.create_ca_signed_cert
    - ca_name: '{{ rabbitmq_ca_name }}'
    - CN: {{ grains['fqdn'] }}
    - require:
        - module: rabbitmq-create-csr
# end create certs
{% endif %}

/etc/rabbitmq/rabbitmq.config:
  file.managed:
    - template: jinja
    - source: salt://templates/rabbitmq.config
    - require:
      - pkg: rabbitmq-server
{% if pillar['rabbitmq-ssl'] %}
      - module: rabbitmq-create-ca-signed-cert
    - context:
      ca_name: {{ rabbitmq_ca_name }}
      cert_path: {{ cert_path }}
{% endif %}
