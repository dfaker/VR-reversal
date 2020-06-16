
from scipy.signal import savgol_filter

ts = []
pitches = []
yaws    = []
rolls   = []
dfovs   = []
closing = ''

for line in open('3dViewHistory.txt','r').readlines():
  parts = line.split()
  if line.startswith('#'):
    closing = line.replace('3dViewHistory','3dViewHistorySmooth')
  elif len(parts)==17:
    timestamp,_,_,_,pitch,_,_,_,yaw,_,_,_,roll,_,_,_,dfov = parts
    ts.append(timestamp)
    pitches.append( float(pitch.replace(',','').replace(';','') ) )
    yaws.append(    float(yaw.replace(',','').replace(';','')   ) ) 
    rolls.append(   float(roll.replace(',','').replace(';','')  ) )
    dfovs.append(   float(dfov.replace(',','').replace(';','')  ) )
  else:
    continue


pitches = savgol_filter(pitches, 9, 3)
yaws    = savgol_filter(yaws,    9, 3)
rolls   = savgol_filter(rolls,   9, 3)
dfovs   = savgol_filter(dfovs,   9, 3)

with open('3dViewHistorySmooth.txt','w') as of:
  for timestamp,pitch,yaw,roll,dfov in zip(ts,pitches,yaws,rolls,dfovs):
    line = "{} [expr] v360 pitch {:.3f}, [expr] v360 yaw {:.3f}, [expr] v360 roll {:.3f}, [expr] v360 d_fov {:.3f};\n".format(
      timestamp,pitch,yaw,roll,dfov                                                                                                                    
    )
    of.write(line)
    print(line)
  of.write(closing)
  print(closing)


