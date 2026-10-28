const button = document.querySelector('.menu');
const nav = document.querySelector('#navigation');
button.addEventListener('click', () => { const open = button.getAttribute('aria-expanded') === 'true'; button.setAttribute('aria-expanded', String(!open)); nav.classList.toggle('open', !open); });
nav.addEventListener('click', e => { if (e.target.closest('a')) { nav.classList.remove('open'); button.setAttribute('aria-expanded', 'false'); } });
document.addEventListener('keydown', e => { if (e.key === 'Escape' && nav.classList.contains('open')) { nav.classList.remove('open'); button.setAttribute('aria-expanded', 'false'); button.focus(); } });
const form = document.querySelector('#quote-form');
let widget, requestId = crypto.randomUUID();
form.addEventListener('submit', async e => {
  e.preventDefault(); if (!form.reportValidity()) return;
  const result=document.querySelector('#quote-result'), button=form.querySelector('button');
  button.disabled=true; result.textContent='Sending your request…';
  try {
    const body=Object.fromEntries(new FormData(form)); body.request_id=requestId;
    const response=await fetch('/api/quote',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body)});
    const data=await response.json(); if(!response.ok || !data.success) throw new Error(data.error || 'Please try again.');
    result.textContent='Your request has been received. We will review the details and contact you to discuss it.'; form.reset(); requestId=crypto.randomUUID();
  } catch(error) {result.textContent=error.message || 'We could not send your request. Please try again.';}
  finally {button.disabled=false;}
});
