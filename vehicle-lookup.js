/* Searchable suggestions; manual values remain valid if the service is unavailable. */
(function(){
 const cache=new Map();let sequence=0;
 async function get(params){const key=params.toString();if(!cache.has(key)){const pending=fetch('/api/lookup?'+key).then(async r=>{if(!r.ok)throw Error('Lookup unavailable');return r.json()}).catch(e=>{cache.delete(key);throw e});cache.set(key,pending)}return cache.get(key)}
 window.attachVehicleLookup=function(form,names){
  if(!form||form.dataset.vehicleLookup)return;form.dataset.vehicleLookup='ready';names=names||{year:'year',make:'make',model:'model'};
  const year=form.querySelector('[name="'+names.year+'"]'),make=form.querySelector('[name="'+names.make+'"]'),model=form.querySelector('[name="'+names.model+'"]');if(!year||!make||!model)return;
  const id='vehicle-lookup-'+(++sequence),makeList=document.createElement('datalist'),modelList=document.createElement('datalist'),status=document.createElement('small');makeList.id=id+'-makes';modelList.id=id+'-models';make.setAttribute('list',makeList.id);model.setAttribute('list',modelList.id);status.setAttribute('role','status');status.className='vehicle-lookup-status';status.textContent='Search suggestions or type a make and model manually.';model.parentElement.append(status);form.append(makeList,modelList);
  const fill=(list,values)=>{list.replaceChildren(...values.map(value=>{const option=document.createElement('option');option.value=value;return option}))};
  let current=0;
  async function models(){const generation=++current,m=make.value.trim(),y=year.value.trim();fill(modelList,[]);if(!m||!/^\d{4}$/.test(y)||+y<1886||+y>2100){status.textContent='Enter a year and make for model suggestions, or type the model manually.';return}status.textContent='Loading model suggestions…';try{const result=await get(new URLSearchParams({kind:'models',make:m,year:y}));if(generation!==current)return;fill(modelList,result.values||[]);status.textContent=result.values?.length?'Choose a model or type it manually.':'No models found; enter the model manually.'}catch{if(generation===current)status.textContent='Model lookup unavailable. Enter the model manually or change the make to retry.'}}
  make.addEventListener('change',models);year.addEventListener('change',models);make.addEventListener('input',()=>{current++;fill(modelList,[])});
  status.textContent='Loading make suggestions; manual entry is available.';get(new URLSearchParams({kind:'makes'})).then(result=>{fill(makeList,result.values||[]);status.textContent='Search suggestions or type a make and model manually.';if(make.value&&year.value)models()}).catch(()=>{status.textContent='Make lookup unavailable. Enter the make and model manually.'});
 };
})();
