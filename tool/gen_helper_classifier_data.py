"""Writes helper/src/ClassifierData.php from lib/domain/classifier.dart.

The helper sorts mail with the same word lists and patterns as the app. They
are copied by this script, never by hand, so the two cannot drift apart.
Run it again whenever classifier.dart changes:

    python tool/gen_helper_classifier_data.py
"""
import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'lib', 'domain', 'classifier.dart')
OUT = os.path.join(ROOT, 'helper', 'src', 'ClassifierData.php')

REGEXES = [
    '_bulkLocalParts', '_softLocalParts', '_automatedName', '_strictReceipt', '_strictNotification', '_strictPromotion', 'otpSubject',
    'travelSubject', 'deliverySubject', '_travelBookingWord', '_deliveryLocalPart', '_moneyMoving', '_codeOffer', '_strictNewsletter',
    '_replyPrefix', '_receiptSubject', '_notificationSubject', '_socialSubject', '_promotionSubject', '_newsletterSubject', '_bounceToken', '_plusToken',
]
SETS = ['sendingSubdomainLabels', 'travelDomains', 'deliveryDomains', 'bulkDomains', '_socialDomains', '_sendingPlatforms']

# Dart's \s also covers these; PHP's does not unless told.
WIDE_SPACE = r'[\s\x{A0}\x{1680}\x{2000}-\x{200A}\x{2028}\x{2029}\x{202F}\x{205F}\x{3000}\x{FEFF}]'


def php_str(s):
    return "'" + s.replace('\\', '\\\\').replace("'", "\\'") + "'"


def main():
    dart = io.open(SRC, encoding='utf-8').read()
    out = ['<?php', 'declare(strict_types=1);', '', 'namespace Precis;', '', '/**',
           ' * Word lists and patterns of the sorter. MADE BY tool/gen_helper_classifier_data.py',
           ' * from lib/domain/classifier.dart. Do not edit by hand: change the Dart file and',
           ' * run the script again.', ' */', 'final class ClassifierData', '{', '    public const RX = [']
    for name in REGEXES:
        m = re.search(r'static final ' + re.escape(name) + r"\s*=\s*RegExp\(\s*r'([^']*)'\s*(,\s*caseSensitive:\s*false)?\s*,?\s*\)", dart, re.S)
        if not m:
            sys.exit('pattern not found: ' + name)
        pattern, insensitive = m.group(1), bool(m.group(2))
        if '~' in pattern:
            sys.exit('pattern holds the delimiter: ' + name)
        if '\\s' in pattern:
            if re.search(r'\[[^\]]*\\s', pattern):
                sys.exit('\\s inside a character class is not handled: ' + name)
            pattern = pattern.replace('\\s', WIDE_SPACE)
        flags = ('i' if insensitive else '') + 'uD'
        out.append('        ' + php_str(name.lstrip('_')) + ' => ' + php_str('~' + pattern + '~' + flags) + ',')
    out.append('    ];')
    out.append('')
    for name in SETS:
        m = re.search(r'static const ' + re.escape(name) + r'\s*=\s*\{(.*?)\};', dart, re.S)
        if not m:
            sys.exit('set not found: ' + name)
        body = re.sub(r'//[^\n]*', '', m.group(1))
        words = re.findall(r"'([^']*)'", body)
        if not words:
            sys.exit('empty set: ' + name)
        const = re.sub(r'(?<!^)(?=[A-Z])', '_', name.lstrip('_')).upper()
        out.append('    public const ' + const + ' = [')
        line = '       '
        for w in words:
            piece = ' ' + php_str(w) + ' => true,'
            if len(line) + len(piece) > 150:
                out.append(line)
                line = '       '
            line += piece
        out.append(line)
        out.append('    ];')
        out.append('')
    out[-1] = '}'
    io.open(OUT, 'w', encoding='utf-8', newline='\n').write('\n'.join(out) + '\n')
    print('wrote', os.path.relpath(OUT, ROOT), '-', len(REGEXES), 'patterns,', len(SETS), 'lists')


if __name__ == '__main__':
    main()
