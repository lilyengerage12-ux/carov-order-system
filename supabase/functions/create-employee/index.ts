import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const cors={"Access-Control-Allow-Origin":"*","Access-Control-Allow-Headers":"authorization, x-client-info, apikey, content-type"};
Deno.serve(async(req)=>{
 if(req.method==="OPTIONS") return new Response("ok",{headers:cors});
 try{
  const auth=req.headers.get("Authorization")||"";
  const url=Deno.env.get("SUPABASE_URL")!;
  const anon=Deno.env.get("SUPABASE_ANON_KEY")!;
  const service=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const userClient=createClient(url,anon,{global:{headers:{Authorization:auth}}});
  const {data:{user},error:userError}=await userClient.auth.getUser();
  if(userError||!user) return json({error:"未登录"},401);
  const admin=createClient(url,service);
  const {data:caller}=await admin.from("profiles").select("role,active").eq("id",user.id).single();
  if(!caller?.active||!["owner","admin"].includes(caller.role)) return json({error:"仅老板或管理员可以创建员工"},403);
  const body=await req.json();
  const phone=String(body.phone||"").trim();
  if(!/^1\d{10}$/.test(phone)) return json({error:"手机号格式不正确"},400);
  if(String(body.password||"").length<8) return json({error:"密码至少8位"},400);
  const email=phone+"@staff.carov.internal";
  if(body.action==="reset_password"){
   const {data:profile}=await admin.from("profiles").select("id").eq("phone",phone).single();
   if(!profile) return json({error:"未找到员工"},404);
   const {error}=await admin.auth.admin.updateUserById(profile.id,{email,password:body.password,email_confirm:true,user_metadata:{phone}});
   if(error) throw error;
   await admin.from("audit_logs").insert({actor_id:user.id,action:"reset_employee_password",target_type:"profile",target_id:profile.id});
   return json({ok:true});
  }
  const {data:existing}=await admin.from("profiles").select("id").eq("phone",phone).maybeSingle();
  if(existing) return json({error:"该手机号已创建员工账号"},409);
  const {data:created,error:createError}=await admin.auth.admin.createUser({email,password:body.password,email_confirm:true,user_metadata:{name:body.name,department:body.department}});
  if(createError) throw createError;
  const staffNo="CRV"+Date.now().toString().slice(-6);
  const {error:updateError}=await admin.from("profiles").update({name:body.name,phone,staff_no:staffNo,department:body.department,role:body.role||"employee",permissions:body.permissions||[],active:body.active!==false,must_change_password:true}).eq("id",created.user.id);
  if(updateError) throw updateError;
  await admin.from("audit_logs").insert({actor_id:user.id,action:"create_employee",target_type:"profile",target_id:created.user.id,details:{phone,staffNo,department:body.department,role:body.role}});
  return json({ok:true,staff_no:staffNo});
 }catch(e){return json({error:e.message||"服务器错误"},400)}
});
function json(data:unknown,status=200){return new Response(JSON.stringify(data),{status,headers:{...cors,"Content-Type":"application/json"}})}
