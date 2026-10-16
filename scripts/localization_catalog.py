from pathlib import Path
import re,json
root=Path(__file__).resolve().parents[1]
messages={}
for path in (root/'game/rebuild').glob('*.gd'):
    if path.stem.endswith('smoke'):continue
    for literal in re.findall(r'"(?:\\.|[^"\\])*"',path.read_text(encoding='utf-8')):
        if re.search('[가-힣]',literal):
            try:value=json.loads(literal)
            except json.JSONDecodeError:continue
            messages[value]=value
(root/'game/rebuild/data/locale_ko.json').write_text(json.dumps(messages,ensure_ascii=False,indent=2),encoding='utf-8')
print('Korean translation source catalog:',len(messages),'messages')
