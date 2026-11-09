export type Role = "parent" | "child";
export const foods = ["apple", "bread", "steak", "bokChoy", "cake", "croissant"];
export function validRole(v: unknown): v is Role { return v === "parent" || v === "child"; }
export function validFood(v: unknown) { return typeof v === "string" && foods.includes(v); }
export function validID(v: unknown): v is string { return typeof v === "string" && /^[a-zA-Z0-9_-]{1,100}$/.test(v); }
export function consumptionAllowed(role: Role, status: string) { return role === "child" && status === "pending"; }
function validZone(zone: string) { try { new Intl.DateTimeFormat("en",{timeZone:zone}); return true; } catch { return false; } }
export function validatePreferences(p: any): boolean {
  return p && typeof p === "object" && typeof p.remindersEnabled === "boolean"
    && Number.isInteger(p.quietStart) && p.quietStart >= 0 && p.quietStart <= 23
    && Number.isInteger(p.quietEnd) && p.quietEnd >= 0 && p.quietEnd <= 23
    && Number.isInteger(p.hungryAfterHours) && p.hungryAfterHours >= 1 && p.hungryAfterHours <= 12
    && Number.isInteger(p.tiredAfterHours) && p.tiredAfterHours > p.hungryAfterHours && p.tiredAfterHours <= 24
    && typeof p.timeZone === "string" && validZone(p.timeZone)
    && Array.isArray(p.schedules) && p.schedules.length === 4
    && new Set(p.schedules.map((s: any)=>s.id)).size === 4
    && p.schedules.every((s: any)=>["Breakfast","Lunch","Dinner","Snack"].includes(s.id)
      && Number.isInteger(s.hour) && s.hour >= 0 && s.hour <= 23
      && Number.isInteger(s.minute) && s.minute >= 0 && s.minute <= 59 && typeof s.enabled === "boolean");
}
export function isQuiet(p: any, now: Date): boolean {
  if (!p || p.quietStart === p.quietEnd) return false;
  const hour = Number(new Intl.DateTimeFormat("en-GB",{timeZone:p.timeZone,hour:"2-digit",hourCycle:"h23"}).format(now));
  return p.quietStart < p.quietEnd ? hour >= p.quietStart && hour < p.quietEnd : hour >= p.quietStart || hour < p.quietEnd;
}
export const defaultPreferences = {
  schedules:[{id:"Breakfast",hour:8,minute:0,enabled:true},{id:"Lunch",hour:12,minute:30,enabled:true},{id:"Dinner",hour:19,minute:0,enabled:true},{id:"Snack",hour:16,minute:0,enabled:false}],
  hungryAfterHours:4,tiredAfterHours:7,remindersEnabled:false,quietStart:22,quietEnd:7,timeZone:"America/New_York"
};
