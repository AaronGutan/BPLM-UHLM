# -*- coding: utf-8 -*-
import re
import sys

sys.stdout.reconfigure(encoding='utf-8')

path = r'e:\1C\AY\BPLM-UHLM-XML\BPLM-UH33LM_remix.xml'
with open(path, 'r', encoding='utf-8-sig') as f:
    lines = f.readlines()

PKO_RANGES = [
    ('СписаниеСРасчетногоСчета', 308679, 314584),
    ('ПоступлениеНаРасчетныйСчет', 440994, 450000),
]

SRC_RE = re.compile(r'Источник Имя="([^"]*)"')
DST_RE = re.compile(r'Приемник Имя="([^"]*)"')
VID_RE = re.compile(r'Вид="([^"]*)"')
NAME_RE = re.compile(r'<Наименование>(.*?)</Наименование>')

for pko_name, approx_start, approx_end in PKO_RANGES:
    start = None
    end = None
    for i in range(approx_start - 1, approx_end):
        if f'<Код>{pko_name}</Код>' in lines[i]:
            for j in range(i, max(approx_start - 30, 0), -1):
                if lines[j].strip().startswith('<Правило'):
                    start = j
                    break
            if start is None:
                start = approx_start - 1
            for j in range(i, approx_end):
                if '</Правило>' in lines[j]:
                    end = j + 1
                    break
            break

    print(f'=== {pko_name} (lines {start + 1}-{end}) ===')
    results = []
    for i in range(start, end):
        line = lines[i]
        if 'Тип="Булево"' not in line:
            continue
        prev = lines[i - 1] if i > 0 else ''
        combined = prev + line
        src_m = SRC_RE.findall(combined)
        dst_m = DST_RE.findall(combined)
        vid_m = VID_RE.findall(combined)
        src = src_m[-1] if src_m else ''
        dst = dst_m[-1] if dst_m else ''
        vid = vid_m[-1] if vid_m else ''
        group = ''
        for j in range(i, max(start, i - 40), -1):
            gm = NAME_RE.search(lines[j])
            if gm:
                group = gm.group(1)
                break
        receiver_only = (src == '' and dst != '')
        results.append((i + 1, src, dst, vid, group, receiver_only))

    print(f'Count: {len(results)}')
    for line_no, src, dst, vid, group, receiver_only in results:
        flag = ' [ТОЛЬКО ПРИЕМНИК]' if receiver_only else ''
        print(f'  L{line_no}: {src or "(пусто)"} -> {dst} ({vid}) | {group}{flag}')
    print()
