# Riedel Lab SIP Server

Asterisk-based SIP server for lab testing and interoperability testing of Riedel SIP audio devices.

The primary purpose of this server is to test SIP communication between current Riedel SIP interfaces and legacy Artist G2 VoIP hardware.

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

---

## 1. Lab Topology

Current validated setup:

    MicroSIP
    Extension 1001
         |
         | SIP + RTP
         |
         v
      Asterisk
    Company NUC
    10.85.30.30
         |
         | SIP + RTP
         |
         v
    Artist G2
    VoIP-108
    Extension 1002
    10.85.226.120

Asterisk acts as the SIP registrar and call router while remaining in the RTP
media path.

MicroSIP provides a known-good reference endpoint when troubleshooting Riedel
hardware.

---

## 2. Asterisk Installation

Install Asterisk:

    sudo apt update
    sudo apt install asterisk

Verify:

    asterisk -V
    sudo systemctl status asterisk --no-pager

The current NUC was validated with Asterisk 20.6.

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

The expected PJSIP transport is:

    transport-udp    udp    10.85.30.30:5060

The lab uses **PJSIP only**.

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

The current transport is bound to:

    10.85.30.30:5060

This IP is specific to the current NUC/network and must be changed when
deploying the repository elsewhere.

---

## 5. SIP Endpoints

The current test endpoints are:

    1001 = MicroSIP
    1002 = Artist G2 VoIP-108

Both endpoints currently use:

    disallow=all
    allow=ulaw

Each endpoint also uses:

    direct_media=no
    force_rport=yes
    rewrite_contact=yes
    rtp_symmetric=yes

---

## 6. Media and NAT Handling

### Asterisk as RTP intermediary

The configuration intentionally uses:

    direct_media=no

This keeps Asterisk in the media path:

    Endpoint A <-- RTP --> Asterisk <-- RTP --> Endpoint B

rather than allowing the endpoints to establish RTP directly.

This is useful for interoperability testing because RTP can be captured and
analyzed centrally on the Asterisk server.

### NAT handling

The following settings are also enabled:

    force_rport=yes
    rewrite_contact=yes
    rtp_symmetric=yes

These became important when testing MicroSIP across NAT.

MicroSIP advertised its local SIP address as:

    192.168.1.215:63696

but Asterisk actually received its traffic from:

    10.85.116.134:63696

Without NAT handling, Asterisk could attempt to send subsequent SIP messages
to the advertised private address instead of the address from which the
traffic actually arrived.

`rewrite_contact=yes` causes Asterisk to rewrite the registered Contact using
the received source address.

The resulting contact was similar to:

    sip:1001@10.85.116.134:63696;ob;
    x-ast-orig-host=192.168.1.215:63696

`force_rport=yes` causes SIP responses to be sent to the IP address and UDP
port from which the request was actually received.

`rtp_symmetric=yes` provides similar behavior for RTP by allowing Asterisk to
send media toward the address/port from which RTP is actually received.

Together with `direct_media=no`, these settings provide predictable SIP and
RTP behavior when clients are behind NAT.

---

## 7. MicroSIP Reference Endpoint

Configure MicroSIP with:

    SIP Server: 10.85.30.30
    Port:       5060
    Transport:  UDP
    Username:   1001
    Login:      1001
    Password:   <configured password>

Verify registration:

    pjsip show endpoint 1001

A normal SIP Digest registration looks like:

    REGISTER
        |
        v
    401 Unauthorized
        |
        v
    REGISTER + Authorization
        |
        v
    200 OK

The initial `401 Unauthorized` is expected. It is the SIP Digest authentication
challenge and does not indicate a failed registration.

---

## 8. Artist G2 VoIP-108 Configuration

The Artist G2 VoIP-108 has been successfully registered as extension `1002`.

### Card / SIP Phone Configuration

Validated settings:

| Setting | Value |
|---|---|
| Domain Server | `10.85.30.30` |
| User Name | `1002` |
| Authentication Name | `1002` |
| Password | Matches Asterisk configuration |
| Re-register | `300 s` |
| Transport | UDP |
| Proxy | Not required |
| Trusted Domain | Not required |
| Auto Hangup | Disabled |

The tested VoIP-108 was reachable at:

    10.85.226.120:5060

Verify registration from Asterisk:

    pjsip show endpoint 1002

A successful registration should show a contact similar to:

    sip:1002@10.85.226.120:5060

---

## 9. Artist G2 VoIP Line Configuration

The SIP Phone configuration controls registration of the VoIP-108.

The individual Artist VoIP line configuration controls how calls are handled.

Validated settings include:

    Phone No. incoming: 1001
    Preferred Audio Codec: G.711 U-law (64Bit/s)
    Invitation (Outgoing call) mode: Manual

### Important: Phone No. incoming

The `Phone No. incoming` field restricts which incoming caller/phone number is
accepted by the Artist VoIP line.

This was important during testing.

With an incorrect value, the VoIP-108 successfully completed SIP setup:

    INVITE
    100 Trying
    200 OK
    ACK

but then immediately terminated the call with:

    BYE

and:

    Reason: SIP;description="User Hung Up."

Because SIP signaling and SDP negotiation had succeeded, this initially
appeared to be an Asterisk or RTP problem.

The cause was the Artist line configuration.

For calls originating from extension `1001`, the working setting was:

    Phone No. incoming = 1001

After correcting this setting, the call remained established.

---

## 10. Codec and RTP Validation

The initial lab codec is:

    G.711 μ-law / PCMU
    RTP Payload Type 0
    8000 Hz
    20 ms packet time

The VoIP-108 advertised support for:

    PCMU
    PCMA
    G.722

PCMU was successfully negotiated.

During testing, the VoIP-108 used RTP port:

    5004

Asterisk successfully relayed bidirectional RTP between MicroSIP and the
VoIP-108.

---

## 11. Dialplan

The current lab dialplan allows both endpoints to call each other:

    [internal]

    exten => 1001,1,Dial(PJSIP/1001,30)
     same => n,Hangup()

    exten => 1002,1,Dial(PJSIP/1002,30)
     same => n,Hangup()

Calls between MicroSIP and the Artist G2 VoIP-108 have been successfully
validated.

---

## 12. Troubleshooting

Connect to Asterisk:

    sudo asterisk -rvvv

Show endpoints:

    pjsip show endpoints

Show individual endpoints:

    pjsip show endpoint 1001
    pjsip show endpoint 1002

Show transport:

    pjsip show transports

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

### Linux Packet Capture

Capture SIP:

    sudo tcpdump -ni enp0s25 -A 'udp port 5060'

Capture traffic to/from the VoIP-108:

    sudo tcpdump -ni enp0s25 host 10.85.226.120

### Common Issues

**PJSIP transport missing**

If:

    pjsip show transports

returns:

    No objects found.

check whether `chan_sip` has claimed UDP/5060:

    sip show settings

---

**Registration exceeds max contacts**

If Asterisk reports:

    Registration attempt ... will exceed max contacts of 1

check for an existing/stale contact:

    pjsip show endpoint 1001
    pjsip show endpoint 1002

---

**SIP call establishes but there is no audio**

Enable:

    rtp set debug on

Check RTP in both directions and verify routing, firewall rules, SDP
addresses, codec negotiation, NAT handling, and RTP ports.

---

**VoIP-108 answers and immediately hangs up**

Check:

    Phone No. incoming

in the Artist VoIP line configuration before changing the Asterisk
configuration.

---

## 13. Git Workflow

Before starting work:

    git pull

Check changes:

    git status
    git diff

After successfully testing a configuration change:

    git add .
    git commit -m "Describe the tested change"
    git push

Only commit configuration changes after they have been tested.

Do not commit production or sensitive SIP credentials to GitHub.

---

## 14. Current Project Status

Validated:

- Asterisk 20 running on the company NUC
- PJSIP UDP transport
- `chan_sip` disabled
- MicroSIP registration
- Artist G2 VoIP-108 registration
- SIP Digest authentication
- MicroSIP ↔ VoIP-108 calling
- G.711 μ-law / PCMU
- Bidirectional RTP
- Asterisk remaining in the RTP path
- NAT handling for MicroSIP
- Artist `Phone No. incoming` behavior

Next milestone:

    IPx16 / Duo <-> Asterisk <-> Artist G2 VoIP-108
