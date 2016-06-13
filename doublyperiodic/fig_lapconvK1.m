function fig_lapconvK1
% Laplace Neu periodic BVP, convergence and soln plots
% Single inclusion (K=1).
% cleaned up from perineu2dnei1.m
% Barnett 5/11/16. Small codes broken out 6/12/16 (no longer self-contained)

warning('off','MATLAB:nearlySingularMatrix')  % backward-stable ill-cond is ok!
warning('off','MATLAB:rankDeficientMatrix')
lso.RECT = true;  % linsolve opts, forces QR even when square (LU much worse),
% ...and much faster than the following backward-stable SVD solve:
%[UE,S,V] = svd(E,'econ'); Sr = max(diag(S),1e-14); co = V*((UE'*rhs)./Sr);

jumps = [1 0]; %[0 1];  % potential jumps across R-L and T-B (not for known sol)

U.e1 = 1; U.e2 = 1i;     % unit cell lattice vectors and src direct sum list...
U.nei = 1; [tx ty] = meshgrid(-U.nei:U.nei); U.trlist = tx(:)+1i*ty(:); % 3x3
m = 22; [U L R B T] = walls(U,m);
proxyrep = @LapSLPmat;   % sets proxy pt type
Rp = 1.4; M = 80;        % proxy params
p.x = Rp * exp(1i*(1:M)'/M*2*pi); p = setupquad(p); % proxy pts

a = 0.7; b = 0.15; % worm params, spills horizontally out of any unit cell
uexdiff = 0.11101745840635; flux1ex = 0.5568613934999;  % a=.7,b=.15.  1e-12
% known soln dipole location: must be deep inside Omega (careful)
src.x = 0.42+.23i; src.w = 1; src.nx = 1+0i;

% -------------------------- single soln and plot
N = 140; s = wormcurve(a,b,N);
rhs = [0*s.x; jumps(1)+0*L.x; 0*L.x; jumps(2)+0*B.x; 0*B.x];   % driving
tic
E = ELSmatrix(s,p,proxyrep,U);              % fill
co = linsolve(E,rhs,lso);                   % direct bkw stable solve
toc
fprintf('resid norm = %.3g\n',norm(E*co - rhs))
sig = co(1:N); psi = co(N+1:end);
fprintf('density norm = %.3g, proxy norm = %.3g\n',norm(sig), norm(psi))
fprintf('density integral = %.3g\n',s.w'*sig) 
z = (.1+.4i)*[-1;1];  % pot difference btw 2 pts (invariant to const shift)...
u = evalsol(s,p,proxyrep,U,z,co);
fprintf('u diff btw two pts = %.16g  \t(est abs err: %.3g)\n',u(2)-u(1), abs(u(2)-u(1)-uexdiff))
tic; J = evalfluxes(s,p,proxyrep,U,co); toc
fprintf('fluxes (%.16g,%.16g)   (est abs err: %.3g)\n',J(1),J(2),J(1)-flux1ex)
if 1   % figure
  utyp = mean(u);
  nx = 300; gx = ((1:nx)/nx*2-1)*Rp;    % eval grid
  gy = gx; [xx yy] = meshgrid(gx,gy); zz = (xx(:)+1i*yy(:)); clear xx yy;
  u = evalsol(s,p,proxyrep,U,zz,co);
  for i=-2:2, for j=-2:2, u(s.inside(zz+U.e1*i+U.e2*j)) = nan; end, end % tidy
  u(abs(zz)>Rp) = nan;   % exclude stuff outside proxy
  u = reshape(u,[nx nx]) - utyp;    % subtract typical value
  figure; contourf(gx,gy,u,[-1.8:.1:1.8]); colormap(jet(256));
  hold on; showsegment(s);
  n=2; for i=-n:n, for j=-n:n, plot([s.x;s.x(1)]+j+1i*i,'-'); end,end
  showsegment({L R T B}); axis equal off; axis([-Rp real(src.x+U.e1) -Rp Rp]);
  plot(z,'k.'); plot(p.x,'r.');
  plot(src.x+U.trlist,'k*');
  text(-.45,0,'L');text(0.55,0,'R'); text(0,-.42,'D');text(0,0.58,'U');
  text(0,0,'$\Omega$','interpreter','latex');
  text(-1.2,1.3,'(a)'); %,'fontsize',14);
  %set(gcf,'paperposition',[0 0 4 4]); print -depsc2 lapsolK1.eps
end

if 1, Ns = 30:10:230;   % ------------------------  N-convergence
us = nan*Ns; res = us; rest = us; ust = us; es = us;
Js = nan(2,numel(Ns)); Jst = Js;
uek = knownsol(U,z,src); % known dipole 3x3 grid soln, fixed, ignores jumps
v = [0*L.w';1+0*L.w';0*B.w';1+0*B.w']; d = ones(M,1)/M; % Sifuentes vectors
for i=1:numel(Ns)
  s = wormcurve(a,b,Ns(i));
  g = [jumps(1)+0*L.x; 0*L.x; jumps(2)+0*B.x; 0*B.x]; rhs = [0*s.x; g]; %driving
  [E,A,Bm,C,Q] = ELSmatrix(s,p,proxyrep,U);
  co = linsolve(E,rhs,lso);
  res(i) = norm(E*co - rhs);
  u = evalsol(s,p,proxyrep,U,z,co);
  us(i) = u(2)-u(1);
  Js(:,i) = evalfluxes(s,p,proxyrep,U,co);
  Qtilde = Q + v*d';  % Schur stuff...
  %if i==1, norm(Q), norm(v*d'), svd(Q), svd(Qtilde), end   % sim size norms?
  QtdagC = linsolve(Qtilde,C,lso); Qtdagg = linsolve(Qtilde,g,lso);
  %Qtdag = pinv(Qtilde); QtdagC = Qtdag*C; Qtdagg = Qtdag*g;  % loses 7 digits
  taut = gmres(@(x) A*x - Bm*(QtdagC*x), -Bm*Qtdagg, [], 1e-14, Ns(i));
  %taut = linsolve(A - Bm*QtdagC,-Bm*Qtdagg,lso);  % direct soln
  %cond(A - Bm*QtdagC)  % 8.4
  xit = Qtdagg - QtdagC*taut; cot = [taut;xit];  % build full soln vector
  rest(i) = norm(E*cot - rhs);      % residual back in ELS
  u = evalsol(s,p,proxyrep,U,z,cot);
  ust(i) = u(2)-u(1);
  Jst(:,i) = evalfluxes(s,p,proxyrep,U,cot);  % Schur flux
  rhsk = knownrhs(src,s,U);     % set up RHS for known 3x3 unit source soln...
  cok = linsolve(E,rhsk,lso);   % coeffs for approx to known soln
  %norm(E*cok - rhsk)    % resid for known soln - plot?
  uk = evalsol(s,p,proxyrep,U,z,cok);       % eval this approx
  es(i) = uk(2)-uk(1)-(uek(2)-uek(1));      % err vs known diff btw test pts
end
fprintf('norm Qt\\C  = %.3g\n',norm(Qtilde\C))
[us',ust',us'-ust']
[Js(1,:)',Jst(1,:)',Js(1,:)'-Jst(1,:)']
[Js(2,:)',Jst(2,:)',Js(2,:)'-Jst(2,:)']
figure; %semilogy(Ns,res,'ro-');  % why is resid always around 1e-14?
semilogy(Ns,abs(us-us(i)),'+-'); hold on;
plot(Ns,abs(Js(1,:)-Js(1,end)),'go-');
plot(Ns,abs(ust-ust(i)),'+--');
plot(Ns,abs(Jst(1,:)-Jst(1,end)),'go--');
%plot(Ns,rest,'rd-');
plot(Ns,abs(es),'ks-');
%legend('u convergence','J_1 convergence','u err vs known');
legend('u conv ELS','J_1 conv ELS','u conv Schur','J_1 conv Schur','u err vs known');
xlabel('N'); text(40,1e-4,'(c)');
text(140,1e-8, sprintf('$M=%d$,     $m=%d$',M,m),'interpreter','latex');
axis([Ns(1) Ns(end-1) 1e-15 1e-3]);
%set(gcf,'paperposition',[0 0 3.5 3.5]); print -depsc2 lapconvK1.eps
end

%keyboard

if 1, Ms = 10:5:120;    % -------------------- M convergence, incl Schur
N = 100; s = wormcurve(a,b,N);  % fixed
rhs = [0*s.x; jumps(1)+0*L.x; 0*L.x; jumps(2)+0*B.x; 0*B.x];   % driving
Js = nan(2,numel(Ms)); nrms = nan*Ms;
nsings = 6; sings = nan(numel(Ms),nsings);   % save some sing vals
for i=1:numel(Ms)
  p.x = Rp * exp(1i*(1:Ms(i))'/Ms(i)*2*pi); p = setupquad(p); % reset proxy pts
  E = ELSmatrix(s,p,proxyrep,U);
  S = svd(E);
  sings(i,1) = max(S); sings(i,2:nsings) = S(end-nsings+2:end); % 1st & last few
  co = linsolve(E,rhs,lso);
  nrms(i) = norm(co);
  Js(:,i) = evalfluxes(s,p,proxyrep,U,co);
end
Js(1,:)'
figure; semilogy(Ms,abs(Js(1,:)-Js(1,end)),'b+-'); hold on;
semilogy(Ms,sings(:,2:end),'-','color',.5*[1 1 1]);
semilogy(Ms,nrms,'b.-');
% *** TODO: bring in K=1e3 M-conv data and add to plot as squares
text(15,max(nrms)/10,'(e)');
text(60,max(nrms)/10,sprintf('$N=%d,   m=%d$',N,m),'interpreter','latex');
xlabel('M'); axis([Ms(1) Ms(end-1) 1e-17 max(nrms)]);
%set(gcf,'paperposition',[0 0 3 3]); print -depsc2 lapMconv.eps
end

if 0 % ------------ Schur tests warm-up (see above for convergence)
  N = 140; s = wormcurve(a,b,N);    % reset curve
  M = 40; p.x = Rp * exp(1i*(1:M)'/M*2*pi); p = setupquad(p); % reset proxy pts
  rhs = [0*s.x; jumps(1)+0*L.x; 0*L.x; jumps(2)+0*B.x; 0*B.x];   % driving
  [E,~,~,C,Q] = ELSmatrix(s,p,proxyrep,U);
  w = [0*L.w';L.w';0*B.w';B.w'];   % consistency vector in Nul Q^T
  fprintf('norm w^T Q = %.3g\n',norm(w'*Q)) 
  fprintf('norm Q\\C  = %.3g\n',norm(Q\C))
  %svd(Q\C) % just one huge sing val, then gap to a decaying sequence.
  %[U S V] = svd(Q); S = diag(S); r = numel(S); figure; plot(U(:,r),'+-');
end



%keyboard
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% end main %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%



function [U L R B T] = walls(U,M)  % setup walls with M nodes for unit cell U
[x w] = gauss(M); w=w/2;
L.x = (-U.e1 + U.e2*x)/2; L.nx = (-1i*U.e2)/abs(U.e2) + 0*L.x; L.w=w*abs(U.e2);
R = L; R.x = L.x + U.e1;
B.x = (-U.e2 + U.e1*x)/2; B.nx = (1i*U.e1)/abs(U.e1) + 0*B.x; B.w=w*abs(U.e1);
T = B; T.x = B.x + U.e2;
U.L = L; U.T = T; U.R = R; U.B = B;

function u = evalsol(s,p,proxyrep,U,z,co)
% z = list of targets as C values. p = proxy struct, s = source curve struct
% co = full coeff vec, U = unit cell struct.  Does potential value only.
N = numel(s.x);
sig = co(1:N); psi = co(N+1:end);  % split up solution coeffs (psi=proxy)
u = proxyrep(struct('x',z), p) * psi;  % init u w/ proxies
for i=1:numel(U.trlist)         % sum potentials faster than srcsum matrices
  u = u + srcsum(@LapSLPmat, U.trlist(i), struct('x',z), s) * sig;  % pot of SLP
end

function J = evalfluxes(s,p,proxyrep,U,co)
% inputs as in evalsol. Uses Gary-inspired bdry of 3x3 block far-field method
if U.nei~=1, warning('U.neu must equal 1'); end
w = U.L.w; if norm(w-U.B.w)>1e-14, error('L and B must have same weights'); end
m = numel(w);
N = numel(s.x); sig = co(1:N); psi = co(N+1:end);
t.x = [U.L.x;U.B.x]; t.nx = [U.L.nx;U.B.nx];  % 2-wall target
[~,Tn] = proxyrep(t, p); u = Tn * psi;   % proxy contrib to un only
J = sum(reshape(u,[m 2])'.*([1;1]*w),2);         % .... do its quadr on L,B 
for i=-1:1      % set up big loop of 12 walls, just their nodes
  x{i+2} = U.L.x - U.e1 +i*U.e2; x{i+5} = x{i+2} + 3*U.e1;
  x{i+8} = U.B.x +i*U.e1 -U.e2; x{i+11} = x{i+8} + 3*U.e2;
end
t.x = vertcat(x{:}); t.nx = [repmat(U.L.nx,[6 1]); repmat(U.B.nx,[6 1])];
[~,Tn] = LapSLPmat(t, s); u = Tn * sig;   % central density only
amts = [0 0 0 3 3 3 -1 -2 -3 1 2 3; -1 -2 -3 1 2 3 0 0 0 3 3 3];  % wall wgts
J = J + sum(repmat(u',[2 1]).*kron(amts,w),2);   % weight each wall

function [E A B C Q] = ELSmatrix(s,p,proxyrep,U)
% builds matrix blocks for extended linear system.
[~,A] = srcsum(@LapSLPmat, U.trlist, s,s);   % directly summed self-int matrix
N = numel(s.x); A = A - eye(N)/2;            % Neumann exterior jump relation
[~,B] = proxyrep(s,p);         % Neu data from proxies
C = Cblock(s,U,@LapSLPmat);
[QL QLn] = proxyrep(U.L,p); [QR QRn] = proxyrep(U.R,p);
[QB QBn] = proxyrep(U.B,p); [QT QTn] = proxyrep(U.T,p);
Q = [QR-QL; QRn-QLn; QT-QB; QTn-QBn];
E = [A B; C Q];

function C = Cblock(s,U,densrep)     % fill C from source curve s to U walls
% densrep is handle to LapSLPmat/LapDLPmat depending on density type on curve s
nei = U.nei; N = numel(s.x); m = numel(U.L.x);
[CL CLn] = srcsum(densrep,nei*U.e1 + (-nei:nei)*U.e2, U.L,s);
[CR CRn] = srcsum(densrep,-nei*U.e1 + (-nei:nei)*U.e2, U.R,s);
[CB CBn] = srcsum(densrep,(-nei:nei)*U.e1 + nei*U.e2, U.B,s);
[CT CTn] = srcsum(densrep,(-nei:nei)*U.e1 - nei*U.e2, U.T,s);
C = [CR-CL; CRn-CLn; CT-CB; CTn-CBn];

function u = knownsol(U,z,src)
% z = targets. U = unit cell struct, src = charge loc.  output potential only
% Note use of dipole (monopole would work, but dipole closer to application)
u = srcsum(@LapDLPmat, U.trlist, struct('x',z), src);  % pot due to DLP

function rhs = knownrhs(src,s,U)
% src is a dipole source with x, w, nx; it will be summed over 3x3, unit mag.
% s is usual target curve (needs normals).
% The rhs will always be consistent, with f and g nonconstant. Matches knownsol.
[~,f] = srcsum(@LapDLPmat,U.trlist,s,src);    % direct Neu data sum to curve
g = Cblock(src,U,@LapDLPmat);
rhs = [f;g];