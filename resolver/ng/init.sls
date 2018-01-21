{% from slspath + "/map.jinja" import resolver with context %}

{{ sls }}~pkg:
  {% if resolver.ng.resolvconf.remove %}
  pkg.purged:
  {% else %}
  pkg.installed:
  {% endif %}
    - name: resolvconf
    - require_in:
      - file: {{ sls }}~update-resolv.conf-file

{{ sls }}~update-resolv.conf-file:
  file.managed:
    {% if resolver.ng.resolvconf.enabled and not resolver.ng.resolvconf.remove %}
    - name: /etc/resolvconf/resolv.conf.d/base
    {% else %}
    - name: /etc/resolv.conf
    - follow_symlinks: False
    {% endif %}
    - user: root
    - group: root
    - mode: '0644'
    - source: salt://{{ slspath }}/templates/resolv.conf.jinja
    - template: jinja
    - defaults:
        nameservers: {{ resolver.nameservers }}
        searchpaths: {{ resolver.searchpaths }}
        options: {{ resolver.options }}
        domain: {{ resolver.domain }}

{% if resolver.ng.resolvconf.enabled and not resolver.ng.resolvconf.remove %}
{{ sls }}~update-resolvconf:
  file.symlink:
    - name: /etc/resolv.conf
    - target: {{ resolver.ng.resolvconf.file }}
    - force: True
  cmd.run:
    - name: resolvconf -u
    - onchanges:
      - file: {{ sls }}~update-resolv.conf-file
{% endif %}

{# Prevent NetworkManager managing resolvconf #}
  {% if salt['file.file_exists'](resolver.ng.networkmanager.file)
        and not resolver.ng.networkmanager.manage_dns %}
    {% for conf in resolver.ng.networkmanager.regex %}

{{ sls }}~networkmanager_dns_{{ conf.name }}:
  file.replace:
    - name: {{ resolver.ng.networkmanager.file }}
    - pattern: {{ conf.search }}
    - repl: {{ conf.replace }}
    - flags: ['IGNORECASE', 'MULTILINE']
    - onlyif: systemctl is-enabled {{ resolver.ng.networkmanager.service }}
    - require:
      - file: {{ sls }}~update-resolv.conf-file
    - watch_in:
      - service: {{ sls }}~networkmanager_dns_{{ conf.name }}
  service.running:
    - name: {{ resolver.ng.networkmanager.service }}
    - enable: True

      {% endfor %}
  {% endif %}
