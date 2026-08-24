# Riedel Lab SIP Server

Asterisk-based SIP server for interoperability testing of Riedel SIP audio devices.

The goal is to provide a simple, reproducible SIP environment for testing current Riedel SIP interfaces with legacy Artist G2 VoIP hardware.

Currently validated:

- Asterisk 20
- MicroSIP
- Artist G2 VoIP-108
- SIP over UDP
- G.711 μ-law (PCMU)
- Bidirectional RTP through Asterisk

Planned hardware testing:

- IPx16 SIP Interface
- Duo SIP Interface

For Artist G2 VoIP-108 configuration and test results, see
[G2.md](G2.md).

---

## 1. Lab Topology

Current validated setup:

    MicroSIP
    Extension 1001
         ↕
         | SIP + RTP
         ↕
      Asterisk
    Company NUC
    10.85.30.30
         ↕
         | SIP + RTP
         ↕
    Artist G2 VoIP-108
    Extension 1002
    10.85.226.120

Asterisk acts as the SIP registrar and call router while intentionally
remaining in the RTP media path.

MicroSIP provides a known-good reference endpoint when introducing or
troubleshooting Riedel hardware.

---

## 2. Asterisk Installation

Install Asterisk:

    sudo apt update
    sudo apt install asterisk

Verify:

    asterisk -V
    sudo systemctl status asterisk --no-pager

The current NUC was validated with:

    Asterisk 20.6

---

## 3. PJSIP and chan_sip

This project uses **PJSIP**.

Asterisk may also load the legacy `chan_sip` channel driver. During initial
deployment, `chan_sip` claimed UDP port 5060 before PJSIP could create its
transport.

The symptom was:

    pjsip show transports

returning:

    No objects found.

while:

    sip show settings

showed:

    UDP Bindaddress: 0.0.0.0:5060

This indicates that `chan_sip` owns UDP/5060.

### Disable chan_sip

Edit:

    sudo nano /etc/asterisk/modules.conf

Under `[modules]`, add:

    noload => chan_sip.so

Restart Asterisk:

    sudo systemctl restart asterisk

Verify:

    sudo asterisk -rvvv

Then:

    module show like chan_sip
    pjsip show transports

`chan_sip` should no longer be loaded and PJSIP should show the configured
UDP transport.

This lab uses **PJSIP only**.

---

## 4. Deploy the Repository Configuration

Git-managed Asterisk configuration files are stored in:

    config/pjsip.conf
    config/extensions.conf

The active Asterisk configuration is located under:

    /etc/asterisk/

Deploy the repository configuration:

    sudo cp config/pjsip.conf /etc/asterisk/pjsip.conf
    sudo cp config/extensions.conf /etc/asterisk/extensions.conf

Restart Asterisk:

    sudo systemctl restart asterisk

Verify:

    sudo asterisk -rvvv

Inside the Asterisk CLI:

    pjsip show transports
    pjsip show endpoints
    dialplan show internal

The current PJSIP transport is bound to:

    10.85.30.30:5060

This address is specific to the current NUC/network and must be changed when
deploying the repository elsewhere.

---

## 5. SIP Endpoints

The current test endpoints are:

    1001 = MicroSIP
    1002 = Artist G2 VoIP-108

Both currently use:

    disallow=all
    allow=ulaw

The endpoint configuration also contains:

    direct_media=no
    force_rport=yes
    rewrite_contact=yes
    rtp_symmetric=yes

---

## 6. Media and NAT Handling

### RTP through Asterisk

The lab intentionally uses:

    direct_media=no

This keeps Asterisk in the media path:

    Endpoint A <-- RTP --> Asterisk <-- RTP --> Endpoint B

rather than allowing the endpoints to establish RTP directly.

Keeping Asterisk in the media path makes packet capture, codec analysis and
interoperability troubleshooting considerably easier.

### NAT handling

The following settings are enabled:

    force_rport=yes
    rewrite_contact=yes
    rtp_symmetric=yes

These became important during MicroSIP testing.

MicroSIP advertised its local SIP address as:

    192.168.1.215:63696

while Asterisk actually received its traffic from:

    10.85.116.134:63696

Without NAT-aware handling, SIP signaling could be sent toward the address
advertised by the client rather than the address through which the client was
actually reachable.

#### rewrite_contact

    rewrite_contact=yes

Asterisk rewrites the registered Contact using the source address from which
the SIP request was received.

During testing, the resulting contact was similar to:

    sip:1001@10.85.116.134:63696;ob;
    x-ast-orig-host=192.168.1.215:63696

#### force_rport

    force_rport=yes

SIP responses are sent to the source IP address and UDP port from which the
request was actually received.

#### rtp_symmetric

    rtp_symmetric=yes

For RTP, Asterisk can send media toward the address/port from which RTP is
actually received instead of relying only on the address advertised in SDP.

Together with `direct_media=no`, these settings provide predictable signaling
and media behavior when endpoints are behind NAT.

---

## 7. MicroSIP Reference Endpoint

MicroSIP can be used as a known-good endpoint before introducing Riedel
hardware.

Example configuration:

    SIP Server: 10.85.30.30
    Port:       5060
    Transport:  UDP
    Username:   1001
    Login:      1001
    Password:   <configured password>

Verify:

    pjsip show endpoint 1001

A normal SIP Digest registration sequence is:

    REGISTER
        ↓
    401 Unauthorized
        ↓
    REGISTER + Authorization
        ↓
    200 OK

The initial `401 Unauthorized` is expected. It is the SIP Digest
authentication challenge and does not indicate a failed registration.

Once MicroSIP is registered and working, it can be used as the reference
endpoint for hardware interoperability testing.

---

## 8. Artist G2 VoIP-108

The Artist G2 VoIP-108 has been successfully validated against this server as
extension `1002`.

Validated functionality includes:

- SIP registration
- SIP Digest authentication
- calls with MicroSIP
- G.711 μ-law / PCMU negotiation
- bidirectional RTP
- call teardown

The Artist configuration contains both **card-level SIP settings** and
**individual VoIP line settings**. Both are required for a working call.

See [G2.md](G2.md) for the validated configuration and troubleshooting notes.

---

## 9. Dialplan

The current lab dialplan allows the two test endpoints to call each other:

    [internal]

    exten => 1001,1,Dial(PJSIP/1001,30)
     same => n,Hangup()

    exten => 1002,1,Dial(PJSIP/1002,30)
     same => n,Hangup()

As additional hardware is introduced, new extensions can be added using the
same structure.

---

## 10. Troubleshooting

Connect to Asterisk:

    sudo asterisk -rvvv

Show endpoints:

    pjsip show endpoints

Show a specific endpoint:

    pjsip show endpoint 1001
    pjsip show endpoint 1002

Show the PJSIP transport:

    pjsip show transports

Show the dialplan:

    dialplan show internal

### SIP Logging

Enable:

    pjsip set logger on

Disable:

    pjsip set logger off

### RTP Logging

Enable:

    rtp set debug on

Disable:

    rtp set debug off

During a working call, RTP packets should be visible in both directions.

### Packet Capture

Capture SIP signaling:

    sudo tcpdump -ni enp0s25 -A 'udp port 5060'

Capture traffic to/from the VoIP-108:

    sudo tcpdump -ni enp0s25 host 10.85.226.120

### Common Issues

**PJSIP transport missing**

If:

    pjsip show transports

returns:

    No objects found.

check:

    sip show settings

If `chan_sip` owns UDP/5060, verify that `chan_sip.so` is disabled in
`/etc/asterisk/modules.conf`.

**Registration exceeds max contacts**

If Asterisk reports:

    Registration attempt ... will exceed max contacts of 1

check the currently stored contact:

    pjsip show endpoint 1001
    pjsip show endpoint 1002

**Call establishes but there is no audio**

Enable:

    rtp set debug on

Then verify RTP in both directions and check routing, firewall rules, SDP
addresses, codec negotiation and NAT handling.

For Artist-specific call behavior, see [G2.md](G2.md).

---

## 11. Git Workflow

Before starting work:

    git pull

Review local changes:

    git status
    git diff

After successfully testing a configuration change:

    git add .
    git commit -m "Describe the tested change"
    git push

Only commit configuration changes after they have been tested.

Do not commit production or sensitive SIP credentials.

---

## 12. Current Project Status

Validated:

- Asterisk 20 running on the company NUC
- PJSIP UDP transport
- `chan_sip` disabled
- MicroSIP registration
- Artist G2 VoIP-108 registration
- SIP Digest authentication
- MicroSIP ↔ VoIP-108 calling
- G.711 μ-law / PCMU
- Bidirectional RTP through Asterisk
- NAT handling for MicroSIP
- Artist G2 incoming-call configuration

Next milestone:

    IPx16 / Duo <-> Asterisk <-> Artist G2 VoIP-108
