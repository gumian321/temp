"""Unprivileged UDP impairment proxy. No firewall, VPN or OS traffic-control changes."""
import socket, select, random, time, heapq, argparse, json
p=argparse.ArgumentParser();p.add_argument('--listen',type=int,required=True);p.add_argument('--server',type=int,required=True);p.add_argument('--seconds',type=float,default=50);p.add_argument('--out',required=True);a=p.parse_args()
rng=random.Random(20261011)
front=socket.socket(socket.AF_INET,socket.SOCK_DGRAM);front.bind(('127.0.0.1',a.listen))
back=socket.socket(socket.AF_INET,socket.SOCK_DGRAM);back.bind(('127.0.0.1',0))
client=None;queue=[];index=0;received=0;received_bytes=0;dropped=0;peak=0;start=time.monotonic()
while time.monotonic()-start<a.seconds:
 for sock in select.select([front,back],[],[],.002)[0]:
  data,addr=sock.recvfrom(65535);received+=1;received_bytes+=len(data)
  if sock is front:client=addr;dest=back;target=('127.0.0.1',a.server)
  else:dest=front;target=client
  if not target:continue
  if rng.random()<.05:dropped+=1;continue
  if len(queue)>=256:dropped+=1;continue
  index+=1;heapq.heappush(queue,(time.monotonic()+rng.uniform(.06,.14),index,dest,target,data));peak=max(peak,len(queue))
 while queue and queue[0][0]<=time.monotonic():
  _,_,sock,target,data=heapq.heappop(queue);sock.sendto(data,target)
json.dump({'received':received,'received_bytes':received_bytes,'mean_bytes_per_second_both_directions':received_bytes/a.seconds,'dropped':dropped,'queue_peak':peak,'one_way_ms':100,'jitter_ms':40,'loss_target':.05,'seed':20261011},open(a.out,'w'),indent=2)
