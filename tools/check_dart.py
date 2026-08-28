import glob,os,re,sys
# Single pass: strings and comments must be handled by ONE walker.
# Stripping // with a regex first also eats the // inside 'https://...',
# leaving an unterminated quote that swallows the rest of the file.
def strip(src):
    out=[];i=0;n=len(src)
    while i<n:
        c=src[i]
        if c=='/' and i+1<n and src[i+1]=='/':
            while i<n and src[i]!='\n':i+=1
            continue
        if c=='/' and i+1<n and src[i+1]=='*':
            i+=2
            while i+1<n and not(src[i]=='*' and src[i+1]=='/'):i+=1
            i+=2;continue
        if c in '"\'':
            q=c
            triple = src[i:i+3]==q*3
            if triple:
                i+=3
                while i+2<n and src[i:i+3]!=q*3:
                    if src[i]=='\\':i+=2;continue
                    i+=1
                i+=3;continue
            i+=1;depth=0
            while i<n:
                if src[i]=='\\':i+=2;continue
                if src[i]=='$' and i+1<n and src[i+1]=='{':
                    depth+=1;out.append('{');i+=2;continue
                if depth>0 and src[i]=='}':
                    depth-=1;out.append('}');i+=1;continue
                if depth>0:
                    out.append(src[i]);i+=1;continue
                if src[i]==q:i+=1;break
                if src[i]=='\n':break
                i+=1
            continue
        out.append(c);i+=1
    return ''.join(out)

fails=0
root=sys.argv[1]
for f in glob.glob(os.path.join(root,'**','*.dart'),recursive=True):
    src=open(f,encoding='utf8').read()
    s=strip(src)
    for op,cl in [('{','}'),('(',')'),('[',']')]:
        if s.count(op)!=s.count(cl):
            print(f'FAIL {f}: {op}{cl} {s.count(op)} vs {s.count(cl)}');fails+=1
    for m in re.finditer(r"import\s+'([^']+)'",src):
        p=m.group(1)
        if p.startswith('package:') or p.startswith('dart:'):continue
        t=os.path.normpath(os.path.join(os.path.dirname(f),p))
        if not os.path.exists(t):
            print(f'FAIL {f}: unresolved import {p}');fails+=1
print(f'FAILURES: {fails}')
sys.exit(1 if fails else 0)
