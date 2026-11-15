export function commissionEstimate(values){
 const gross=Number(values.gross),rate=Number(values.rate),fixed=Number(values.fixed||0);
 if(String(values.gross??'').trim()===''||String(values.rate??'').trim()===''||![gross,rate,fixed].every(Number.isFinite)||gross<0||gross>10000000||rate<0||rate>100||fixed<0||fixed>gross)throw new Error('Use an amount up to ZMW 10,000,000, a rate from 0–100%, and a fixed fee no greater than the amount.');
 const grossMinor=Math.round(gross*100),feeMinor=Math.round(grossMinor*rate/100)+Math.round(fixed*100);
 if(feeMinor>grossMinor)throw new Error('Combined assumed fees exceed the amount.');
 return {grossMinor,feeMinor,netMinor:grossMinor-feeMinor,rate,fixedMinor:Math.round(fixed*100)};
}
export const weekDays=['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
export function hoursSummary(rows){
 if(!Array.isArray(rows)||rows.length!==7)throw new Error('Provide all seven days.');
 return rows.map((row,index)=>{
  if(row.closed)return `${weekDays[index]}: Closed`;
  if(!/^([01]\d|2[0-3]):[0-5]\d$/.test(row.open)||!/^([01]\d|2[0-3]):[0-5]\d$/.test(row.close)||row.close<=row.open)throw new Error(`${weekDays[index]}: closing time must follow opening time on the same day.`);
  return `${weekDays[index]}: ${row.open}–${row.close}`;
 }).join('\n');
}
