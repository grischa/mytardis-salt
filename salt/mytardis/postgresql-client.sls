postgresql-client:
  pkg.installed:
{% if grains['os_family'] == "Debian" %}
    - name: postgresql-client
{% else %}
    - name: postgresql
{% endif %}
