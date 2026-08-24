# Artist G2 VoIP-108 Integration

This document describes the validated Artist G2 VoIP-108 configuration for
the Riedel Lab SIP Server.

For Asterisk installation, PJSIP configuration, NAT handling and general
troubleshooting, see [README.md](README.md).

---

## 1. Validated Setup

The Artist G2 VoIP-108 was tested as extension `1002` against the Asterisk
server running on the company NUC.

    MicroSIP
    Extension 1001
         ↕
         | SIP + RTP
         ↕
      Asterisk
    10.85.30.30
         ↕
         | SIP + RTP
         ↕
    Artist G2 VoIP-108
    Extension 1002
    10.85.226.120

Validated:

- registration to Asterisk/PJSIP
- SIP Digest authentication
- incoming calls
- outgoing calls
- G.711 μ-law / PCMU
- bidirectional RTP
- normal call teardown

---

## 2. Asterisk Endpoint

The VoIP-108 uses extension:

    1002

The corresponding PJSIP endpoint is configured for:

    disallow=all
    allow=ulaw
    direct_media=no
    force_rport=yes
    rewrite_contact=yes
    rtp_symmetric=yes

Verify registration from Asterisk:

    pjsip show endpoint 1002

A successful registration should show a contact similar to:

    sip:1002@10.85.226.120:5060

and Asterisk should report the endpoint as reachable.

---

## 3. VoIP-108 Card / SIP Phone Configuration

The VoIP-108 card contains the SIP account/server configuration used to
register with Asterisk.

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

The tested card used:

    10.85.226.120

and registered to:

    10.85.30.30:5060

A successful registration follows the normal SIP Digest exchange:

    VoIP-108                       Asterisk
       |                               |
       | REGISTER                      |
       |------------------------------>|
       |                               |
       | 401 Unauthorized              |
       |<------------------------------|
       |                               |
       | REGISTER + Authorization      |
       |------------------------------>|
       |                               |
       | 200 OK                        |
       |<------------------------------|

The initial `401 Unauthorized` is expected.

---

## 4. VoIP Line Configuration

Registration of the card alone is not sufficient.

The individual Artist VoIP line also determines how incoming and outgoing
calls are handled.

Validated line settings include:

    Phone No. incoming: 1001
    Preferred Audio Codec: G.711 U-law (64Bit/s)
    Invitation (Outgoing call) mode: Manual

The distinction is important:

    Card / SIP Phone configuration
              |
              +--> SIP registration

    VoIP Line configuration
              |
              +--> call behavior

A card can therefore be successfully registered while a call still fails
because of the line configuration.

---

## 5. Phone No. incoming

The `Phone No. incoming` field was the most important Artist-specific finding
during initial testing.

It restricts which incoming caller/phone number is accepted by the configured
VoIP line.

For the validated test:

    MicroSIP extension = 1001

therefore the working Artist setting was:

    Phone No. incoming = 1001

### Failure Behavior

With an incorrect incoming number, SIP signaling initially appeared healthy.

The VoIP-108 received the call and completed:

    INVITE
       ↓
    100 Trying
       ↓
    200 OK
       ↓
    ACK

The call therefore reached an established SIP dialog.

The VoIP-108 then immediately sent:

    BYE

including:

    Reason: SIP;description="User Hung Up."

This initially suggested an Asterisk, SDP, codec or RTP problem.

However, the SIP server configuration was valid. The call was being rejected
by the Artist line configuration after SIP setup.

Correcting:

    Phone No. incoming = 1001

resolved the issue and the call remained established.

### Troubleshooting Rule

If the VoIP-108:

1. registers successfully,
2. responds to an INVITE with `200 OK`,
3. receives the ACK,
4. then immediately sends a BYE,

check **Phone No. incoming** before changing the Asterisk configuration.

---

## 6. Codec Negotiation

Asterisk currently offers:

    G.711 μ-law / PCMU

Example SDP:

    m=audio <port> RTP/AVP 0 101
    a=rtpmap:0 PCMU/8000
    a=rtpmap:101 telephone-event/8000
    a=ptime:20
    a=sendrecv

During testing, the VoIP-108 advertised:

    PCMU
    PCMA
    G.722
    telephone-event

Example:

    m=audio 5004 RTP/AVP 0 8 9 101
    a=rtpmap:0 PCMU/8000
    a=rtpmap:8 PCMA/8000
    a=rtpmap:9 G722/8000
    a=rtpmap:101 telephone-event/8000
    a=ptime:20
    a=sendrecv

PCMU was successfully negotiated.

---

## 7. RTP

During the validated test, the VoIP-108 advertised:

    RTP:  10.85.226.120:5004
    RTCP: 10.85.226.120:5005

Because the lab uses:

    direct_media=no

RTP passes through Asterisk:

    MicroSIP
        ↕
       RTP
        ↕
    Asterisk
        ↕
       RTP
        ↕
    VoIP-108

Bidirectional RTP was successfully validated.

To inspect RTP:

    sudo asterisk -rvvv

then:

    rtp set debug on

Disable afterward:

    rtp set debug off

---

## 8. SIP Debugging

Enable PJSIP packet logging:

    pjsip set logger on

The important stages for a call from extension `1001` to the VoIP-108 are:

    1001
      |
      | INVITE
      v
    Asterisk
      |
      | INVITE
      v
    VoIP-108 1002
      |
      | 100 Trying
      | 200 OK
      v
    Asterisk
      |
      | 200 OK
      v
    1001

followed by ACK and bidirectional RTP.

Disable logging when finished:

    pjsip set logger off

Linux packet capture can also be used:

    sudo tcpdump -ni enp0s25 host 10.85.226.120

---

## 9. Known-Good Checklist

Before troubleshooting a VoIP-108 call, verify in this order:

1. Asterisk PJSIP transport is running on UDP/5060.
2. Endpoint `1002` is registered.
3. The VoIP-108 card/SIP Phone credentials match Asterisk.
4. The Artist VoIP line is configured.
5. `Phone No. incoming` matches the expected incoming caller.
6. G.711 μ-law / PCMU is available.
7. SIP INVITE/200 OK/ACK completes.
8. RTP is visible in both directions.

This order helps distinguish:

    registration problem
          ↓
    SIP signaling problem
          ↓
    Artist line configuration problem
          ↓
    codec / SDP problem
          ↓
    RTP / network problem

---

## 10. Validated Result

The Artist G2 VoIP-108 has been successfully integrated with the lab Asterisk
server.

Validated path:

    MicroSIP 1001
         ↕
    Asterisk / PJSIP
         ↕
    Artist G2 VoIP-108 1002

The main Artist-specific lesson from initial integration was that successful
SIP registration does not guarantee that the configured VoIP line will accept
a call.

In particular, `Phone No. incoming` must be considered when a call completes
SIP setup but is immediately terminated by the VoIP-108.

The next interoperability test is:

    IPx16 / Duo
         ↕
      Asterisk
         ↕
    Artist G2 VoIP-108
