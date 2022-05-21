# faradaynet

[Wireguard](https://www.wireguard.com/) examples using network namespaces.

## Two nodes only

| Device  | Namespace | type      | peer      | IP addr     | wg listen port | wg endpoint    |
| ------  | --------- | ----      | ----      | -------     | -------------- | -----------    |
| `a_eth` | `net_a`   | veth      | `b_eth`   | 10.0.0.1/24 | N/A            | N/A            |
| `b_eth` | `net_b`   | veth      | `a_eth`   | 10.0.0.2/24 | N/A            | N/A            |
| `a_wg`  | `net_a`   | wireguard | 10.0.50.2 | 10.0.50.1   | 51801          | 10.0.0.2:51802 |
| `b_wg`  | `net_b`   | wireguard | 10.0.50.2 | 10.0.50.1   | 51802          | 10.0.0.1:51801 |

* `sudo ./wg_in_netns.sh`

## Central node + 2 satellites

* Según network:
  * `A <--> bridge <--> B`
  * `          ^`
  * `          |--> C`
* Según wireguard: ` A <--> B <--> C`

| Device   | Namespace | type      | peer        | IP addr     | wg listen port |
| ------   | --------- | ----      | ----        | -------     | -------------- |
| `brbr`   | N/A       | bridge    | N/A         | N/A         | N/A            |
| `a_eth`  | `net_a`   | veth      | `a_br_eth`  | 10.0.0.1/24 | N/A            |
| `b_eth`  | `net_b`   | veth      | `b_br_eth`  | 10.0.0.2/24 | N/A            |
| `c_eth`  | `net_c`   | veth      | `c_br_eth`  | 10.0.0.3/24 | N/A            |
| `a_wg`   | `net_a`   | wireguard |  10.0.50.2  | 10.0.50.1   | 51801          |
| `b_wg`   | `net_b`   | wireguard | 50.1 y 50.3 | 10.0.50.2   | 51801          |
| `c_wg`   | `net_c`   | wireguard | 10.0.50.2   | 10.0.50.3   | 51801          |

* `sudo ./central_node.sh`
