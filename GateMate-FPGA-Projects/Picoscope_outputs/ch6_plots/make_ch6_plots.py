"""Plots and timing values of Chapter 6, made from the PicoScope CSV exports.
Needs: numpy, matplotlib.  Reads ../Final_outputs (waveform CSV) and ./decoder_csv (decoder tables)."""
import csv, glob, os, json, statistics, collections
import numpy as np, matplotlib
matplotlib.use('Agg'); import matplotlib.pyplot as plt
HERE=os.path.dirname(os.path.abspath(__file__))
D=os.path.join(HERE,'decoder_csv')
W=os.path.join(HERE,'..','Final_outputs')
def load(f):
    rows=[]
    for r in csv.DictReader(open(f)):
        try: rows.append((int(r['Buffer Number']),float(r['Start Time']),float(r['End Time']),int(r['Data'].strip(),16)))
        except (ValueError, KeyError): pass
    return rows

# ---- word periods (answer words sent back to back) ----
caps=sorted(set(os.path.basename(f).rsplit('_t',1)[0] for f in glob.glob(D+'/*.csv')))
fwd=[];per=[];fwd_by=collections.Counter()
slow={'LedData_ValidLedSopAsDataAfterPrevData','LedData_InvalidSopAsData'}
for c in caps:
    t={i:load(f'{D}/{c}_t{i}.csv') for i in (1,2,3,4)}
    for buf in set(r[0] for r in t[1]):
        A=[r for r in t[1] if r[0]==buf]; C=[r for r in t[3] if r[0]==buf]
        if c not in slow:
            for a in A:
                m=[x for x in C if 9e-6< x[1]-a[1] <12e-6]
                if m: fwd.append((m[0][1]-a[1])*1e6); fwd_by[c]+=1
        for ch in (2,4):
            words=sorted([r for r in t[ch] if r[0]==buf],key=lambda r:r[1])
            for x,y in zip(words,words[1:]):
                d=(y[1]-x[1])*1e6
                if d<12: per.append(d)
print(caps)
print('fwd',len(fwd),min(fwd),max(fwd),statistics.mean(fwd)); print(fwd_by)
print('per',len(per),min(per),max(per),statistics.mean(per))

# ---- forwarding delay from interpolated start edges ----
def wave_csv(cap,buf):
    f=glob.glob(f'{W}/*_{cap}/*_{cap}_{buf}.csv')
    if not f: return None
    a=np.genfromtxt(f[0],delimiter=',',skip_header=3)
    return a
def fall(t,v,t0,th=1.1):
    # first crossing high->low within t0-0.5us..t0+0.6us ; t in s
    i=np.searchsorted(t,t0-0.5e-6); j=np.searchsorted(t,t0+0.6e-6)
    for k in range(i,j):
        if v[k]>=th and v[k+1]<th:
            return t[k]+(v[k]-th)/(v[k]-v[k+1])*(t[k+1]-t[k])
    return None
caps=sorted(set(os.path.basename(f).rsplit('_t',1)[0] for f in glob.glob(D+'/*.csv')))
res=[]
for c in caps:
    t={i:load(f'{D}/{c}_t{i}.csv') for i in (1,3)}
    for buf in sorted(set(r[0] for r in t[1])):
        w=wave_csv(c,buf)
        if w is None: continue
        tt=w[:,0]*1e-3
        if abs((tt[1]-tt[0])-1e-7)>1e-9: continue
        A=[r for r in t[1] if r[0]==buf]; C=[r for r in t[3] if r[0]==buf]
        for a in A:
            m=[x for x in C if 9e-6< x[1]-a[1] <12e-6]
            if not m: continue
            ea=fall(tt,w[:,1],a[1]); ec=fall(tt,w[:,3],m[0][1])
            if ea and ec: res.append((c,buf,a[3],(ec-ea)*1e6))
d=[r[3] for r in res]

print('forwarding delay:',len(d),'words, min %.2f, max %.2f, mean %.2f us'%(min(d),max(d),statistics.mean(d)))

# ---- figures ----
COL={'A':'#2a78d6','B':'#eb6834','C':'#1baf7a','D':'#eda100'}
NAME={'A':'A  PC → GM1','C':'C  GM1 → GM2','D':'D  GM2 → GM1','B':'B  GM1 → PC'}
IDX={'A':1,'B':2,'C':3,'D':4}
INK='#0b0b0b'; INK2='#52514e'; GRID='#e4e3df'
plt.rcParams.update({'font.family':'DejaVu Sans','font.size':8,'axes.edgecolor':INK2,'axes.labelcolor':INK,
    'xtick.color':INK2,'ytick.color':INK2,'axes.spines.top':False,'axes.spines.right':False,'lines.linewidth':1.0})
def wave(cap,buf):
    a=np.genfromtxt(glob.glob(f'{W}/*_{cap}/*_{cap}_{buf}.csv')[0],delimiter=',',skip_header=3)
    return a[:,0]*1e3, a  # time in us
dec={k:load(f'{D}/LedData_Valid_t{IDX[k]}.csv') for k in IDX}
def save(fig,name):
    fig.savefig(name+'.pdf',bbox_inches='tight'); fig.savefig(name+'.svg',bbox_inches='tight'); fig.savefig(name+'.png',dpi=200,bbox_inches='tight')

# ---------- Figure 1: forwarding delay ----------
t,w=wave('LedData_Valid',2)
fig,ax=plt.subplots(figsize=(6.3,2.4))
m=(t>-2)&(t<25)
for k,off in (('A',3.0),('C',0.0)):
    ax.plot(t[m],w[m,IDX[k]]+off,color=COL[k])
    ax.text(-2.3,off+1.1,NAME[k],ha='right',va='center',color=INK,fontsize=8)
ta=0.0; tc=10.7
for x in (ta,tc): ax.axvline(x,color=INK2,lw=0.6,ls=(0,(2,2)))
ax.annotate('',xy=(tc,5.9),xytext=(ta,5.9),arrowprops=dict(arrowstyle='<->',color=INK,lw=0.8))
ax.text((ta+tc)/2,6.15,'10.7 µs',ha='center',va='bottom',color=INK)
ax.axvline(10.5,color=INK2,lw=0.6,ls=(0,(1,1.5)))
ax.text(10.3,-0.75,'middle of stop bit (10.5 µs)',ha='right',va='center',color=INK2,fontsize=7)
ax.text(5.5,4.6,'word 0x100 received (11 bits)',ha='center',color=INK2,fontsize=7)
ax.text(15.6,-0.75,'same word sent on to GM2',ha='center',color=INK2,fontsize=7)
ax.set_yticks([]); ax.spines['left'].set_visible(False)
ax.set_xlim(-2,25); ax.set_ylim(-1.1,6.8); ax.set_xlabel('time after the start edge on A (µs)')
save(fig,'ch6_plot_forwarding_delay'); plt.close(fig)

# ---------- Figure 2: decoded packets as 4 lanes ----------
wins=[(1,1168,1200,'(a) Count packet: count value'),(1,2255,2345,'(b) Count packet: EOP and answers'),
      (2,2915,3150,'(c) LED packet: data bytes'),(2,5150,5262,'(d) LED packet: EOP and answers')]
order=['A','C','D','B']
fig,axs=plt.subplots(2,2,figsize=(6.3,4.6),gridspec_kw={'width_ratios':[1.25,1.6],'hspace':0.55,'wspace':0.08})
for ax,(buf,t0,t1,title) in zip(axs.flat,wins):
    t,w=wave('LedData_Valid',buf); m=(t>=t0)&(t<=t1)
    for j,k in enumerate(order):
        off=(3-j)*3.4
        ax.plot(t[m],w[m,IDX[k]]+off,color=COL[k],lw=0.8)
        if ax in axs[:,0]:
            ax.text(t0-(t1-t0)*0.04,off+1.1,NAME[k],ha='right',va='center',fontsize=7.5,color=INK)
        if title.startswith('(c)'):
            rs=[r for r in dec[k] if r[0]==buf and t0<=r[1]*1e6<=t1]
            if rs:
                xa=rs[0][1]*1e6; xb=rs[-1][2]*1e6
                ax.plot([xa,xb],[off+2.75]*2,color=INK2,lw=0.6)
                ax.text(xa if k=='C' else (xa+xb)/2,off+2.9,'%d bytes: %s … %s'%(len(rs),'%03X'%rs[0][3],'%03X'%rs[-1][3]),ha='left' if k=='C' else 'center',va='bottom',fontsize=6,color=INK,bbox=dict(fc='white',ec='none',pad=0.5))
            continue
        for r in dec[k]:
            if r[0]==buf and t0<=r[1]*1e6<=t1-3:
                xc=(r[1]+r[2])/2*1e6
                ax.text(xc,off+2.55,'%03X'%r[3],ha='center',va='bottom',fontsize=5.6,color=INK)
    ax.set_title(title,fontsize=8,loc='left',color=INK)
    ax.set_xlim(t0,t1); ax.set_ylim(-0.6,14.2); ax.set_yticks([]); ax.spines['left'].set_visible(False)
    ax.set_xlabel('time (µs)',fontsize=7); ax.tick_params(labelsize=7)
save(fig,'ch6_plot_decoded_packets'); plt.close(fig)

# ---------- Figure 3: statistics ----------
fe=[r[3] for r in res]

fig,(a1,a2)=plt.subplots(1,2,figsize=(6.3,2.3),gridspec_kw={'wspace':0.35})
bins=np.arange(10.595,10.735,0.01)
a1.hist(fe,bins=bins,color=COL['C'],edgecolor='#fcfcfb',linewidth=1.5)
a1.axvline(10.65,color=INK,lw=1,ls=(0,(3,2))); a1.text(10.648,a1.get_ylim()[1]*0.95,'simulation\n10.65 µs',ha='right',va='top',fontsize=7,color=INK)
a1.axvline(np.mean(fe),color=COL['A'],lw=1.2); a1.text(np.mean(fe)+0.003,a1.get_ylim()[1]*0.95,'mean\n%.2f µs'%np.mean(fe),ha='left',va='top',fontsize=7,color=INK)
a1.set_xticks([10.60,10.65,10.70]); a1.set_xlabel('forwarding delay in GM1 (µs)'); a1.set_ylabel('number of words'); a1.set_title('(a) 96 forwarded words',fontsize=8,loc='left')
vals,cnt=np.unique(np.round(per,1),return_counts=True)
a2.bar(vals,cnt,width=0.06,color=COL['B'])
for v,c in zip(vals,cnt): a2.text(v,c+1.5,str(c),ha='center',fontsize=7,color=INK)
a2.axvline(11.04,color=INK,lw=1,ls=(0,(3,2))); a2.text(11.045,max(cnt)*0.8,'expected\n11.04 µs',ha='left',fontsize=7,color=INK)
a2.set_xticks(vals); a2.set_xlim(10.9,11.3); a2.set_ylim(0,max(cnt)*1.2)
a2.set_xlabel('start-to-start time of two answer words (µs)'); a2.set_title('(b) 144 word pairs',fontsize=8,loc='left')
for a in (a1,a2): a.grid(axis='y',color=GRID,lw=0.6); a.set_axisbelow(True)
save(fig,'ch6_plot_timing_stats'); plt.close(fig)
print(len(fe),np.mean(fe),vals,cnt)

_cache={}
def wave(cap,buf):
    k=(cap,buf)
    if k not in _cache:
        a=np.genfromtxt(glob.glob(f'{W}/*_{cap}/*_{cap}_{buf}.csv')[0],delimiter=',',skip_header=3)
        _cache[k]=(a[:,0]*1e3,a)
    return _cache[k]
def lanes(panels,name,ratios):
    fig,axs=plt.subplots(2,2,figsize=(6.3,4.6),gridspec_kw={'width_ratios':ratios,'hspace':0.55,'wspace':0.12})
    for ax,(cap,buf,t0,t1,title,group) in zip(axs.flat,panels):
        dec={k:load(f'{D}/{cap}_t{IDX[k]}.csv') for k in IDX}
        t,w=wave(cap,buf); m=(t>=t0)&(t<=t1)
        for j,k in enumerate(['A','C','D','B']):
            off=(3-j)*3.4
            ax.plot(t[m],w[m,IDX[k]]+off,color=COL[k],lw=0.8)
            if ax in axs[:,0]:
                ax.text(t0-(t1-t0)*0.04,off+1.1,NAME[k],ha='right',va='center',fontsize=7.5,color=INK)
            rs=[r for r in dec[k] if r[0]==buf and t0<=r[1]*1e6<=t1-2]
            if group and len(rs)>=4:
                xa=rs[0][1]*1e6; xb=rs[-1][2]*1e6
                ax.plot([xa,xb],[off+2.75]*2,color=INK2,lw=0.6)
                ax.text(xa,off+2.9,'%d bytes: %03X … %03X'%(len(rs),rs[0][3],rs[-1][3]),ha='left',va='bottom',fontsize=6,color=INK,bbox=dict(fc='white',ec='none',pad=0.5))
            else:
                for r in rs:
                    ax.text((r[1]+r[2])/2*1e6,off+2.55,'%03X'%r[3],ha='center',va='bottom',fontsize=5.6,color=INK)
            if not rs and k in ('B','D') and 'EOP' in title:
                ax.text(t1-(t1-t0)*0.02,off+1.6,'no word',ha='right',va='bottom',fontsize=6,color=INK2,style='italic')
        ax.set_title(title,fontsize=8,loc='left',color=INK)
        ax.set_xlim(t0,t1); ax.set_ylim(-0.6,14.2); ax.set_yticks([]); ax.spines['left'].set_visible(False)
        ax.set_xlabel('time (µs)',fontsize=7); ax.tick_params(labelsize=7)
    for e in ('pdf','svg','png'): fig.savefig(f'{name}.{e}',bbox_inches='tight',**({'dpi':200} if e=='png' else {}))
    plt.close(fig)

# Count Segments: boundary case B2 (0xFE) and error case B5 (control word as count value)
lanes([('CountSegmentsFE',1,1105,1140,'(a) B2: count value FE in, FF out',False),
       ('CountSegmentsFE',1,2282,2365,'(b) B2: both nodes answer (FE, FF)',False),
       ('CountSegmentsInvalidSopAsData',1,1062,1095,'(c) B5: control word 150 as count',False),
       ('CountSegmentsInvalidSopAsData',1,2170,2250,'(d) B5: EOP, no answer',False)],
      'ch6_plot_count_errors',[1,1.6])
# LED data: short packet C5 (12 bytes) and error case C9 (control word inside the data)
lanes([('LedData_12Bytes',2,2228,2412,'(a) C5: 12 data bytes in, 4 sent on',True),
       ('LedData_12Bytes',2,4186,4250,'(b) C5: EOP, only GM1 answers',False),
       ('LedData_InvalidSopAsData',2,6030,6075,'(c) C9: control word 110 in the data',False),
       ('LedData_InvalidSopAsData',2,12035,12110,'(d) C9: EOP, no answer',False)],
      'ch6_plot_led_errors',[1.25,1.6])
print('ok')
