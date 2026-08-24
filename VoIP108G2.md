# Artist G2 VoIP-108 Integration

This document describes the validated Artist G2 VoIP-108 configuration for
the Riedel Lab SIP Server.

For Asterisk installation, PJSIP configuration, NAT handling, and general
troubleshooting, see [README.md](README.md).

For IPx16-specific configuration, see [IPX16.md](IPX16.md).

---

## 1. Validated Setup

The Artist G2 VoIP-108 was tested as extension `1002` against the Asterisk
server running on the company NUC.

The VoIP-108 has been validated with both MicroSIP and IPx16 endpoints:

    MicroSIP 1001                    IPx16 1003
         ↕                               ↕
         +--------- SIP + RTP -----------+
                       ↕
                    Asterisk
                  10.85.30.30
                       ↕
                   SIP + RTP
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
- MicroSIP ↔ VoIP-108 calling
- IPx16 ↔ VoIP-108 calling

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

The initial `401 Unauthorized` is expected. It is the SIP Digest
authentication challenge and does not indicate a failed registration.

---

## 4. VoIP Line Configuration

Registration of the card alone is not sufficient.

The individual Artist VoIP line determines how incoming and outgoing calls
are handled.

Validated line settings include:

    Phone No. incoming: <calling extension>
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
during interoperability testing.

It restricts which incoming caller/phone number is accepted by the configured
VoIP line.

The value must match the SIP caller identity presented to the VoIP-108.

Validated examples:

    MicroSIP 1001 -> VoIP-108 1002
    Phone No. incoming = 1001

    IPx16 1003 -> VoIP-108 1002
    Phone No. incoming = 1003

Changing the calling endpoint therefore requires the corresponding
`Phone No. incoming` value to be considered on the Artist VoIP line.

### Failure Behavior

With an incorrect incoming number, SIP signaling can initially appear
healthy.

The VoIP-108 can receive the call and complete:

    INVITE
       ↓
    100 Trying
       ↓
    200 OK
       ↓
    ACK

The call therefore reaches an established SIP dialog.

The VoIP-108 then immediately sends:

    BYE

including:

    Reason: SIP;description="User Hung Up."

This behavior initially suggested an Asterisk, SDP, codec, or RTP problem.

However, the SIP server configuration was valid. The call was being
terminated because the Artist VoIP line did not accept the incoming caller
identity.

Correcting `Phone No. incoming` to match the calling extension resolved the
problem and allowed the call to remain established.

This behavior was reproduced with both MicroSIP and IPx16 callers.

### Troubleshooting Rule

If the VoIP-108:

1. registers successfully,
2. responds to an INVITE with `200 OK`,
3. receives the ACK,
4. then immediately sends a BYE,

check **Phone No. incoming** before changing the Asterisk configuration.

---

## 6. Codec Negotiation

Asterisk currently allows:

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

The IPx16 was configured with G.722 as its preferred codec but successfully
negotiated G.711 μ-law / PCMU through Asterisk.

---

## 7. RTP

The lab is configured with:

    direct_media=no

This keeps Asterisk in the media path:

    Endpoint A
        ↕
       RTP
        ↕
    Asterisk
        ↕
       RTP
        ↕
    VoIP-108

During the validated test, the VoIP-108 advertised:

    RTP:  10.85.226.120:5004
    RTCP: 10.85.226.120:5005

Bidirectional RTP was successfully validated.

To inspect RTP, connect to the Asterisk CLI:

    sudo asterisk -rvvv

Enable RTP debugging:

    rtp set debug on

Disable it afterward:

    rtp set debug off

---

## 8. SIP Debugging

Enable PJSIP packet logging:

    pjsip set logger on

For an incoming call to the VoIP-108, the expected signaling flow is:

    Calling Endpoint
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
    Calling Endpoint

This is followed by ACK and bidirectional RTP.

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
5. `Phone No. incoming` matches the calling extension.
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

Validated paths:

    MicroSIP 1001
         ↕
    Asterisk / PJSIP
         ↕
    Artist G2 VoIP-108 1002

and:

    IPx16 1003
         ↕
    Asterisk / PJSIP
         ↕
    Artist G2 VoIP-108 1002

The main Artist-specific lesson is that successful SIP registration does not
guarantee that the configured VoIP line will accept an incoming call.

In particular, `Phone No. incoming` must match the calling extension. An
incorrect value can result in apparently successful SIP call establishment
followed by an immediate BYE from the VoIP-108.

The Artist G2 VoIP-108 has now been validated with both MicroSIP and IPx16
endpoints through Asterisk.
