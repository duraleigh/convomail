<?php
declare(strict_types=1);

namespace Precis;

/**
 * Word lists and patterns of the sorter. MADE BY tool/gen_helper_classifier_data.py
 * from lib/domain/classifier.dart. Do not edit by hand: change the Dart file and
 * run the script again.
 */
final class ClassifierData
{
    public const RX = [
        'bulkLocalParts' => '~^(no-?reply|do-?not-?reply|donotreply|noreply-[\\w.-]+|[\\w.-]*-?noreply|[\\w.-]*-?no-reply|notifications?|notify|alerts?|mailer-daemon|postmaster|newsletters?|digest|updates?|bounces?|[\\w.-]*bounce[\\w.-]*|marketing|promotions?|promos?|news|enews|support-noreply|automated|auto-?confirm|confirm(ation)?s?|orders?|receipts?|billing|invoices?|statements?|security|account(s)?|team|robot|bot|system|daemon|ping|welcome|rewards|loyalty|members(hip)?|member-?services|community|events?|invitations?|invites?|surveys?|feedback|care|customer-?care|customer-?support|customer-?experience|guest-?services|reservations?|bookings?|shipping|tracking|deliver(y|ies)|verify|verification|otp|passwords?|reminders?|status|offers?|deals?|store|shop|mailer|mailings?|bulk|blast|campaigns?|helpdesk|help-?desk)$~iuD',
        'softLocalParts' => '~^(info|hello|hi|contact|mail|email|admin|help|service|services|customerservice|customer-service|sales|support|office|inquiries|enquiries)$~iuD',
        'automatedName' => '~(\\b(newsletters?|news|notifications?|no.?reply|customer (care|service|support|experience)|rewards|marketing|digest|billing|orders?|alerts?|help ?desk|support|member services|guest services|reservations|do not reply)\\b|\\bteam$|^the .+ team$)~iuD',
        'strictReceipt' => '~\\b(receipt|order (confirmation|confirmed|#|number|received|placed)|your order|payment (received|confirmation|successful|processed)|statement is (ready|available)|bill is ready|your (bill|statement)|refund|subscription (renewal|renewed|receipt))\\b~iuD',
        'strictNotification' => '~\\b(security alert|sign-?in|new login|verify your|verification code|one-?time (passcode|password|code)|passcode|your code|password (reset|changed)|2-?step|two-?factor|account (activity|update)|new device|mentioned you|assigned to you|pull request|build (failed|passed|succeeded)|job alert)\\b~iuD',
        'strictPromotion' => '~(\\d{1,2}% off|\\$\\d+ off|free shipping|coupon|promo code|limited time|last chance|ends (tonight|today|soon)|black friday|cyber monday|clearance|flash sale|new arrivals|just dropped|gift guide|bogo|shop now|% off)~iuD',
        'otpSubject' => '~\\b(verification code|verify code|one-?time (passcode|password|pass ?code|code|pin)|passcode|otp|security code|log ?in code|sign-?in code|access code|authentication code|auth code|2-?step (verification )?code|two-?(factor|step) (authentication )?code|is your [\\w .-]{1,40} code|your [\\w-]+ code is|code to (sign|log) ?in|magic (link|code))\\b~iuD',
        'travelSubject' => '~\\b(boarding pass|your (flight|trip|itinerary|stay|hotel|car rental|train|e-?ticket)s?\\b|flight (confirmation|itinerary|receipt|reservation|change|update|status|delay(ed)?|cancell?ation|cancell?ed|reminder)|(online )?check[- ]?in (is )?(now )?(open|available|for your)|time to check[- ]?in|trip (confirmation|details|itinerary|reminder)|itinerary|e-?ticket|(hotel|room|stay) (confirmation|reservation|booking|receipt|folio)|reservation (confirmed|confirmation|for your stay)|booking (confirmation|confirmed|details|reference)|upcoming (stay|trip|flight)|car rental|rental car|rental (agreement|confirmation|reservation|receipt)|vehicle (pick-?up|return)|train (ticket|reservation|booking|confirmation|journey)|rail (ticket|pass|reservation)|seat (assignment|selection|upgrade)|gate change|departure (time|gate|reminder)|layover|amtrak|eurostar)\\b~iuD',
        'deliverySubject' => '~\\b(shipped|has shipped|have shipped|shipping (confirmation|update|notification)|ship(ment|ping) (update|notification|confirmation|status)|shipment|on (its|the) way|out for delivery|delivered|delivery (update|confirmation|attempt|exception|scheduled|notification|status|window|today|tomorrow)|arriving (today|tomorrow|soon|early|late|on|by)|arrives (today|tomorrow|on|by)|will arrive|is arriving|now arriving|package|parcel|tracking (number|update|info|information)|track your (order|package|shipment|delivery)|in transit|ready for pick-?up|was picked up|delayed delivery)\\b~iuD',
        'travelBookingWord' => '~\\b(confirm(ed|ation)|itinerary|reservation|booking|trip|check[- ]?in|boarding|receipt|stay|rental|ticket|flight|seat|gate|departure|arrival|pick-?up|cancel(l?ed|lation)?)\\b~iuD',
        'deliveryLocalPart' => '~shipment|tracking|shipping|delivery~uD',
        'moneyMoving' => '~\\b(payouts?|transfers?|deposits?|funds|refunds?|payments?|money|cash|wire)\\b~iuD',
        'codeOffer' => '~promo|coupon|discount|gift|referral|reward|voucher|% off|\\bsale\\b|\\boff\\b~iuD',
        'strictNewsletter' => '~\\b(newsletter|digest|issue #?\\d+|this week in|the week in|top stories|in case you missed)\\b~iuD',
        'replyPrefix' => '~^[\\s\\x{A0}\\x{1680}\\x{2000}-\\x{200A}\\x{2028}\\x{2029}\\x{202F}\\x{205F}\\x{3000}\\x{FEFF}]*(re|fw|fwd|aw|sv|tr)[\\s\\x{A0}\\x{1680}\\x{2000}-\\x{200A}\\x{2028}\\x{2029}\\x{202F}\\x{205F}\\x{3000}\\x{FEFF}]*:~iuD',
        'receiptSubject' => '~\\b(receipt|invoice|order (confirmation|confirmed|#|number|received|update|placed)|your order|ordered|payment (received|confirmation|successful|processed)|purchase|statement is (ready|available)|bill is ready|your (bill|statement)|transaction|refund|subscription (renewal|renewed|receipt))\\b~iuD',
        'notificationSubject' => '~\\b(security alert|sign-?in|new login|verify (your|this)|verification code|one-?time (passcode|password|code)|passcode|otp|your code|password (reset|changed)|2-?step|two-?factor|reminder|alert|action required|confirm your|account (activity|update)|was (added|removed|changed)|new device|mentioned you|assigned to you|commented|new comment|pull request|build (failed|passed|succeeded)|run failed|deployment|job alert|appointment)\\b~iuD',
        'socialSubject' => '~\\b(friend request|followed you|new follower|tagged you|liked your|commented on your|mentioned you in|sent you a message|wants to connect|connection request|invitation to connect|new message from|reacted to|shared a post|is live|new post from)\\b~iuD',
        'promotionSubject' => '~(\\d{1,2}% off|% off|\\$\\d+ off|sale\\b|deal(s)?\\b|offer(s)?\\b|save (up to|\\$|\\d)|free shipping|coupon|promo|limited time|last chance|ends (tonight|today|soon)|don.t miss|black friday|cyber monday|clearance|exclusive|flash sale|new arrivals|just dropped|gift guide|bogo|rewards|points)~iuD',
        'newsletterSubject' => '~\\b(newsletter|digest|weekly|daily|monthly|edition|issue #?\\d+|roundup|round-up|this week in|the week in|top stories|briefing|bulletin|recap|what.s new|in case you missed)\\b~iuD',
        'bounceToken' => '~^(bounces?|bnc|prvs|srs[01]|btv1|msprvs1|return|reply|replies)[+=_.-]~iuD',
        'plusToken' => '~\\+[a-z0-9_.=-]*\\d[a-z0-9_.=-]{6,}$~iuD',
    ];

    public const SENDING_SUBDOMAIN_LABELS = [
        'e' => true, 'em' => true, 'email' => true, 'emails' => true, 'mail' => true, 'mailer' => true, 'mailers' => true, 'mailing' => true,
        't' => true, 'tr' => true, 'tx' => true, 'txn' => true, 'trans' => true, 'transactional' => true, 'm' => true, 's' => true, 'go' => true,
        'mg' => true, 'news' => true, 'newsletter' => true, 'newsletters' => true, 'enews' => true, 'info' => true, 'hello' => true,
        'no-reply' => true, 'noreply' => true, 'notification' => true, 'notifications' => true, 'notify' => true, 'alert' => true, 'alerts' => true,
        'update' => true, 'updates' => true, 'confirmation' => true, 'confirmations' => true, 'servicenotification' => true, 'campaign' => true,
        'campaigns' => true, 'account' => true, 'accounts' => true, 'loyalty' => true, 'care' => true, 'ecom' => true, 'marketing' => true,
        'promo' => true, 'promos' => true, 'offers' => true, 'reply' => true, 'bounce' => true, 'bounces' => true, 'engage' => true, 'comms' => true,
        'communications' => true, 'comunicaciones' => true, 'smtp' => true, 'send' => true, 'mta' => true, 'delivery' => true, 'crm' => true,
        'msg' => true, 'messages' => true, 'list' => true, 'lists' => true, 'members' => true, 'rewards' => true, 'store' => true, 'shop' => true,
        'order' => true, 'orders' => true, 'receipts' => true, 'billing' => true, 'customer' => true, 'customercare' => true, 'community' => true,
        'events' => true, 'invite' => true, 'invites' => true, 'link' => true, 'links' => true, 'click' => true, 'digest' => true, 'bulletin' => true,
        'response' => true, 'auto' => true, 'automail' => true,
    ];

    public const TRAVEL_DOMAINS = [
        'delta.com' => true, 'aa.com' => true, 'united.com' => true, 'southwest.com' => true, 'iflysouthwest.com' => true, 'jetblue.com' => true,
        'alaskaair.com' => true, 'spirit.com' => true, 'flyfrontier.com' => true, 'hawaiianairlines.com' => true, 'allegiantair.com' => true,
        'suncountry.com' => true, 'britishairways.com' => true, 'ba.com' => true, 'aircanada.com' => true, 'aircanada.ca' => true,
        'lufthansa.com' => true, 'airfrance.com' => true, 'airfrance.fr' => true, 'klm.com' => true, 'emirates.com' => true,
        'qatarairways.com' => true, 'virginatlantic.com' => true, 'aerlingus.com' => true, 'icelandair.com' => true, 'westjet.com' => true,
        'aeromexico.com' => true, 'latam.com' => true, 'singaporeair.com' => true, 'cathaypacific.com' => true, 'qantas.com' => true,
        'turkishairlines.com' => true, 'expedia.com' => true, 'expediamail.com' => true, 'booking.com' => true, 'hotels.com' => true,
        'priceline.com' => true, 'kayak.com' => true, 'orbitz.com' => true, 'travelocity.com' => true, 'hopper.com' => true, 'tripit.com' => true,
        'trip.com' => true, 'agoda.com' => true, 'airbnb.com' => true, 'vrbo.com' => true, 'homeaway.com' => true, 'marriott.com' => true,
        'email-marriott.com' => true, 'hilton.com' => true, 'hyatt.com' => true, 'ihg.com' => true, 'choicehotels.com' => true,
        'wyndhamhotels.com' => true, 'bestwestern.com' => true, 'radissonhotels.com' => true, 'accor.com' => true, 'fourseasons.com' => true,
        'omnihotels.com' => true, 'hertz.com' => true, 'avis.com' => true, 'budget.com' => true, 'enterprise.com' => true, 'nationalcar.com' => true,
        'alamo.com' => true, 'sixt.com' => true, 'turo.com' => true, 'thrifty.com' => true, 'dollar.com' => true, 'amtrak.com' => true,
        'eurostar.com' => true, 'thetrainline.com' => true, 'trainline.com' => true, 'viarail.ca' => true, 'brightline.com' => true,
        'flixbus.com' => true, 'greyhound.com' => true,
    ];

    public const DELIVERY_DOMAINS = [
        'ups.com' => true, 'fedex.com' => true, 'usps.com' => true, 'usps.gov' => true, 'dhl.com' => true, 'dhl.de' => true, 'ontrac.com' => true,
        'lasership.com' => true, 'narvar.com' => true, 'aftership.com' => true, 'route.com' => true, 'shipstation.com' => true,
        'canadapost.ca' => true, 'royalmail.com' => true, 'purolator.com' => true, 'veho.com' => true,
    ];

    public const BULK_DOMAINS = [
        'mailchimp.com' => true, 'list-manage.com' => true, 'mcsv.net' => true, 'rsgsv.net' => true, 'sendgrid.net' => true, 'sendgrid.me' => true,
        'amazonses.com' => true, 'mailgun.org' => true, 'mailgun.net' => true, 'constantcontact.com' => true, 'ccsend.com' => true,
        'createsend.com' => true, 'cmail19.com' => true, 'cmail20.com' => true, 'exacttarget.com' => true, 'et.e.mail' => true,
        'sailthru.com' => true, 'klaviyo.com' => true, 'klaviyomail.com' => true, 'hubspotemail.net' => true, 'hs-send.com' => true,
        'substack.com' => true, 'substackcdn.com' => true, 'beehiiv.com' => true, 'convertkit.com' => true, 'ck.page' => true,
        'mailerlite.com' => true, 'sparkpostmail.com' => true, 'postmarkapp.com' => true, 'mandrillapp.com' => true, 'braze.com' => true,
        'iterable.com' => true, 'customeriomail.com' => true, 'drip.com' => true, 'activehosted.com' => true, 'getresponse.com' => true,
        'aweber.com' => true, 'campaign-archive.com' => true, 'e.emailsrvr.com' => true, 'sfcustomeremail.com' => true, 'salesforce.com' => true,
        'marketo.com' => true, 'mktomail.com' => true, 'pardot.com' => true, 'emarsys.net' => true, 'responsys.net' => true, 'bronto.com' => true,
        'listrak.com' => true, 'attentivemobile.com' => true, 'omnisend.com' => true, 'sendinblue.com' => true, 'brevo.com' => true,
        'mailjet.com' => true, 'facebookmail.com' => true, 'linkedin.com' => true, 'twitter.com' => true, 'instagram.com' => true,
        'nextdoor.com' => true, 'pinterest.com' => true, 'tiktok.com' => true, 'redditmail.com' => true, 'reddit.com' => true, 'discord.com' => true,
        'slack.com' => true, 'youtube.com' => true, 'quora.com' => true, 'meetup.com' => true, 'strava.com' => true, 'snapchat.com' => true,
        'threads.net' => true, 'github.com' => true, 'gitlab.com' => true, 'atlassian.net' => true, 'atlassian.com' => true, 'trello.com' => true,
        'dropbox.com' => true, 'docusign.net' => true, 'docusign.com' => true, 'paypal.com' => true, 'stripe.com' => true, 'squareup.com' => true,
        'venmo.com' => true, 'intuit.com' => true, 'quickbooks.com' => true, 'shopify.com' => true, 'amazon.com' => true, 'ebay.com' => true,
        'etsy.com' => true, 'uber.com' => true, 'lyft.com' => true, 'doordash.com' => true, 'grubhub.com' => true, 'instacart.com' => true,
        'airbnb.com' => true, 'booking.com' => true, 'expedia.com' => true, 'hotels.com' => true, 'ticketmaster.com' => true,
        'eventbrite.com' => true, 'zillow.com' => true, 'indeed.com' => true, 'glassdoor.com' => true, 'accounts.google.com' => true,
        'google.com' => true, 'apple.com' => true, 'icloud.com' => true, 'microsoft.com' => true, 'microsoftonline.com' => true, 'live.com' => true,
        'spotify.com' => true, 'netflix.com' => true, 'hulu.com' => true, 'disneyplus.com' => true, 'adobe.com' => true, 'zoom.us' => true,
        'calendly.com' => true, 'medium.com' => true, 'patreon.com' => true, 'kickstarter.com' => true, 'coinbase.com' => true,
        'robinhood.com' => true, 'chase.com' => true, 'bankofamerica.com' => true, 'wellsfargo.com' => true, 'capitalone.com' => true,
        'americanexpress.com' => true, 'discover.com' => true, 'citi.com' => true, 'usps.com' => true, 'ups.com' => true, 'fedex.com' => true,
        'dhl.com' => true,
    ];

    public const SOCIAL_DOMAINS = [
        'facebookmail.com' => true, 'linkedin.com' => true, 'twitter.com' => true, 'instagram.com' => true, 'nextdoor.com' => true,
        'pinterest.com' => true, 'tiktok.com' => true, 'redditmail.com' => true, 'reddit.com' => true, 'discord.com' => true, 'slack.com' => true,
        'youtube.com' => true, 'quora.com' => true, 'meetup.com' => true, 'strava.com' => true, 'snapchat.com' => true, 'threads.net' => true,
    ];

    public const SENDING_PLATFORMS = [
        'mailchimp.com' => true, 'list-manage.com' => true, 'mcsv.net' => true, 'rsgsv.net' => true, 'sendgrid.net' => true, 'sendgrid.me' => true,
        'amazonses.com' => true, 'mailgun.org' => true, 'mailgun.net' => true, 'constantcontact.com' => true, 'ccsend.com' => true,
        'createsend.com' => true, 'exacttarget.com' => true, 'sailthru.com' => true, 'klaviyomail.com' => true, 'hubspotemail.net' => true,
        'hs-send.com' => true, 'sparkpostmail.com' => true, 'postmarkapp.com' => true, 'mandrillapp.com' => true, 'customeriomail.com' => true,
        'customer.io' => true, 'mktomail.com' => true, 'pardot.com' => true, 'emarsys.net' => true, 'responsys.net' => true, 'mailjet.com' => true,
        'mailtrack.io' => true, 'intercom-mail.com' => true, 'zendesk.com' => true, 'freshdesk.com' => true, 'hubspot.com' => true,
    ];
}
