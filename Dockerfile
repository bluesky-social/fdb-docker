FROM foundationdb/foundationdb:7.3.63

COPY scripts/fdb-entrypoint.bash /var/fdb/scripts/fdb-entrypoint.bash
RUN chmod +x /var/fdb/scripts/fdb-entrypoint.bash

ENTRYPOINT ["/usr/bin/tini", "-g", "--", "/var/fdb/scripts/fdb-entrypoint.bash"]
