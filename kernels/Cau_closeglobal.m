function [vc vcp vcpp] = Cau_closeglobal(x,s,vb,side,o)
% CAU_CLOSEGLOBAL.  Globally compensated barycentric int/ext Cauchy integral
%
% This is a spectrally-accurate close-evaluation scheme for Cauchy integrals.
%  It returns approximate values (and possibly first derivatives) of a function
%  either holomorphic inside of, or holomorphic and decaying outside of, a
%  closed curve, given a set of its values on nodes of a smooth global
%  quadrature rule for the curve (such as the periodic trapezoid rule).
%  This is done by approximating the Cauchy integral
%
%       v(x) =  +- (1/(2i.pi)) integral_Gamma v(y) / (x-y) dy,
%
%  where Gamma is the curve, the sign is + (for x interior) or - (exterior),
%  using special barycentric-type formulae which are accurate arbitrarily close
%  to the curve.
%
%  By default, for the value these formulae are (23) for interior and (27) for
%  exterior, from [hel08], before taking the real part.  The interior case
%  is originally due to [ioak]. For the derivative, the Schneider-Werner formula
%  (Prop 11 in [sw86]; see [berrut]) is used to get v' at the nodes, then since
%  v' is also holomorphic, it is evaluated using the same scheme as v.  This
%  "interpolate the derivative" suggestion of Trefethen (personal communication,
%  2014) contrasts [lsc2d] which "differentes the interpolant". The former gives
%  around 15 digits for values v, 14 digits for interior derivatives v', but
%  only 13 digits for exterior v'. (The other [lsc2d] scheme gives 14 digits
%  in the last case; see options below).  The paper [lsc2d] has key background,
%  and is helpful to understand [hel08] and [sw86].  This code replaces code
%  referred to in [lsc2d].
%
%  The routine can (when vb is empty) instead return the full M-by-N dense
%  matrices mapping v at the nodes to values (and derivatives) at targets.
%
% Basic use:  v = Cau_closeglobal(x,s,vb,side)
%             [v vp] = Cau_closeglobal(x,s,vb,side)
%             [v vp vpp] = Cau_closeglobal(x,s,vb,side)
%
% Inputs:
%  x = row or col vec of M target points in complex plane
%  s = closed curve struct containing a set of vectors with N items each:
%       s.x  = smooth quadrature nodes on curve, points in complex plane
%       s.w  = smooth weights for arc-length integrals (scalar "speed weights")
%       s.nx = unit normals at nodes (unit magnitude complex numbers)
%  vb = col vec (or stack of such) of N boundary values of holomorphic function
%       v. If empty, causes outputs to be the dense matrix/matrices.
%  side = 'i' or 'e' specifies if all targets interior or exterior to curve.
%
% Outputs:
%  v  = col vec (or stack of such) approximating the homolorphic function v
%       at the M targets
%  vp = col vec (or stack of such) approximating the complex first derivative
%       v' at the M targets
%  vpp = col vec (or stack of such) approximating the complex 2nd derivative
%       v'' at the M targets
%
% Without input arguments, a self-test is done outputting errors at various
%  distances from the curve for a fixed N. (Needs setupquad.m)
%
% Notes:
% 1) For accuracy, the smooth quadrature must be accurate for the boundary data
%  vb, and it must come from a holomorphic function (be in the right Hardy
%  space).
% 2) For the exterior case, v must vanish at infinity.
% 3) The algorithm is O(NM) in time. In order to vectorize in both sources and
%  targets, it is also O(NM) in memory - using loops this could of course be
%  reduced to O(N+M). If RAM is a limitation, targets should be blocked into
%  reasonable numbers and a separate call done for each).
%
% If vb is empty, the outputs v and vp are instead the dense evaluation
%  matrices, and the time cost is O(N^2M) --- this should be rewritten.
%
% Advanced use: [vc ...] = Cau_closeglobal(x,s,vb,side,opts) allows control of
% options, for experts, such as
%   opts.delta : switches to a lecagy [lsc2d] scheme for v', which is
%                non-barycentric for distances beyond delta, but O(N) slower
%                for distances closer than delta. This achieves around 1 extra
%                digit for v' in the exterior case. I recommend delta=1e-2.
%                Note, v'' (vpp) is not available with this scheme.
%                For this scheme, s must have the following extra field:
%                    s.a  = a point in the "deep" interior of curve (far from
%                           the boundary)
%                delta=0 never uses the barycentric form for v', loses digits
%                in v' as target approaches source.
%
% References:
%
%  [sw86]  C. Schneider and W. Werner, Some new aspects of rational
%          interpolation, Math. Comp., 47 (1986), pp. 285–299
%
%  [ioak]  N. I. Ioakimidis, K. E. Papadakis, and E. A. Perdios, Numerical
%          evaluation of analytic functions by Cauchy’s theorem, BIT Numer.
%          Math., 31 (1991), pp. 276–285
%
%  [berrut] J.-P. Berrut and L. N. Trefethen, Barycentric Lagrange
%          interpolation, SIAM Review, 46 (2004), pp. 501-517
%
%  [hel08] J. Helsing and R. Ojala, On the evaluation of layer potentials close
%          to their sources, J. Comput. Phys., 227 (2008), pp. 2899–292
%
%  [lsc2d] Spectrally-accurate quadratures for evaluation of layer potentials
%          close to the boundary for the 2D Stokes and Laplace equations,
%          A. H. Barnett, B. Wu, and S. Veerapaneni, SIAM J. Sci. Comput.,
%          37(4), B519-B542 (2015)   https://arxiv.org/abs/1410.2187
%
% See also: test/FIG_CAU_CLOSEGLOBAL, SETUPQUAD.
%
% Todo: * allow mixed interior/exterior targets, and/or auto-detect this.
% * O(N) faster matrix filling version!
% * Think about if interface should be t.x.
% Note in/output format changed to col vecs, 6/27/16

% (c) Alex Barnett, June 2016, based on code from 10/22/13. Blocked 8/2/16
% 2nd deriv added, Oct. 2018, Jun Wang, Flatiron Inst.
% Barnett sped up by at least 20x, via all O(N^2.Nc) via GEMM, tidied, 5/4/19

if nargin<1, test_Cau_closeglobal; return; end
if nargin<5, o = []; end    
N = numel(s.x);
if isempty(vb)                  % do matrix filling version (N data col vecs)
  if nargout==1, vc = Cau_closeglobal(x,s,eye(N),side,o);
  elseif nargout==2, [vc vcp] = Cau_closeglobal(x,s,eye(N),side,o); 
  else, [vc vcp vcpp] = Cau_closeglobal(x,s,eye(N),side,o); end
  return
end
if isfield(o,'delta')            % use legacy versions from LSC2D paper...
  if ~isfield(s,'a')
    error('s.a interior pt needed to use legacy lsc2d version');
  end
  if nargout==1, vc = cauchycompeval_lsc2d(x,s,vb,side,o); 
  else, [vc vcp] = cauchycompeval_lsc2d(x,s,vb,side,o); end 
  return
end

M = numel(x); Nc = size(vb,2);   % # targets, # input col vecs
 
% Note: only multi-vector version now (faster even for Nc=1 single-vec).
% (Note: is non-optimal as method for matrix filling when case vb=sparse)
% Do bary interp for value outputs:
% Precompute weights in O(NM)... note sum along 1-axis faster than 2-axis...
comp = repmat(s.cw, [1 M]) ./ (repmat(s.x,[1 M]) - repmat(x(:).',[N 1]));
% mult input vec version (transp of Wu/Marple): comp size N*M, I0 size M*Nc
I0 = blockedinterp(vb,comp);    % local func, directly below
J0 = sum(comp).';  % size N*1, Ioakimidis notation
if side=='e', J0 = J0-2i*pi; end                      % Helsing exterior form
vc = I0./(J0*ones(1,Nc));                 % bary form (multi-vec), size M*Nc
[jj ii] = ind2sub(size(comp),find(~isfinite(comp)));  % node-targ coincidences
for l=1:numel(jj), vc(ii(l),:) = vb(jj(l),:); end     % replace each hit w/ corresp vb

if nargout>1   % 1st deriv also wanted... Trefethen idea first get v' @ nodes
  Y = 1 ./ bsxfun(@minus,s.x,s.x.'); Y(diagind(Y))=0;  % j.ne.i Cauchy mat
  Y = Y .* (s.cw*ones(1,N));      % include complex wei over 1st index
  Y(diagind(Y)) = -sum(Y).';    % set diag to: -sum_{j.ne.i} w_j/(y_j-y_i)
  vbp = Y.'*vb;                 % v' @ nodes, size N*Nc
  if side=='e', vbp = vbp + 2i*pi*vb; end    % S-W variant derived 6/12/16...
  vbp = ((-1./s.cw)*ones(1,Nc)).*vbp;
  % now again do bary interp of v' using its value vbp at nodes...
  I0 = blockedinterp(vbp,comp);
  J0 = sum(comp).';
  if side=='e', J0 = J0-2i*pi; end                    % Helsing exterior form
  vcp = I0./(J0*ones(1,Nc));                          % bary form
  for l=1:numel(jj), vcp(ii(l),:) = vbp(jj(l),:); end % replace hits w/ vbp
end

if nargout>2   % 2nd deriv, mult-col version; we use vcp and Y from 1st deriv
  vbpp = Y.'*vbp;                 % v'' @ nodes, size N*Nc
  if side=='e', vbpp = vbpp + 2i*pi*vbp; end  % S-W variant derived 6/12/16
  vbpp = ((-1./s.cw)*ones(1,Nc)).*vbpp;
  % now again do bary interp of v'' 
  I0 = blockedinterp(vbpp,comp);
  % J0 computed above in the nargout>1 case
  vcpp = I0./(J0*ones(1,Nc));                          % bary form
  for l=1:numel(jj), vcpp(ii(l),:) = vbpp(jj(l),:); end % replace hits w/ vbp
end
%%%%%

function I0 = blockedinterp(vb,comp)   % ....................................
% perform barycentric interpolation using precomputed comp wei mat, used in
% multi-density vec version above. Output: I0 (size M*Nc).
% Barnett 5/4/19
I0 = (vb.'*comp).';    % unbelievable we didn't notice this GEMM earlier :)


%%%%%%%%%%%%%%%%%%%%%%%%%
function test_Cau_closeglobal     % test self-reproducing of Cauchy integrals
N = 400; 
s = wobblycurve(1,0.3,5,N);   % smooth wobbly radial shape params
tic;
%profile clear; profile on;    % (uncomment to profile; and at end)
format short g
for side = 'ie'       % test Cauchy formula for holomorphic funcs in and out...
  a = 1.1+1i; if side=='e', a = .1+.5i; end % pole, dist 0.5 from G, .33 for ext
  v = @(z) 1./(z-a); vp = @(z) -1./(z-a).^2;   % used in paper
  vpp = @(z) 2./(z-a).^3;

  z0 = s.x(floor(N/4));
  ds = logspace(0,-18,10).'*(.1-1i); % displacements (col vec)
  if side=='e', ds = -ds; end % flip to outside
  z = z0 + ds; z(end) = z0; % ray of pts heading to a node, w/ last hit exactly
  vz = v(z); vpz = vp(z); vppz = vpp(z); M = numel(z);
  %d = repmat(s.x(:),[1 M])-repmat(z(:).',[N 1]); % displ mat for...
  %vc = sum(repmat(v(s.x).*s.cw,[1 M])./d,1)/(2i*pi); % naive Cauchy (so bad!)
  [vc vcp vcpp] = Cau_closeglobal(z,s,v(s.x),side);    % current version
  %s.a=0; [vc vcp] = Cau_closeglobal(z,s,v(s.x),side,struct('delta',.01)); % oldbary alg, 0.5-1 digit better for v' ext, except at the node itself, where wrong.
  err = abs(vc - vz); errp = abs(vcp - vpz);
  errpp = abs(vcpp -vppz);
  disp(['side ' side ':  dist        v err       v'' err     v'''' err'])
  [abs(imag(ds)) err errp errpp]
   
  % test multi-col-vec inputs & mat filling:
  [vcm vcpm vcppm] = Cau_closeglobal(z,s,[v(s.x),0.5*v(s.x)],side); % basic Nc=2 case
  fprintf('  multi-col test: %.3g %.3g %.3g\n',max(abs(vcm(:,1)-vz)), max(abs(vcpm(:,1)-vpz)), max(abs(vcppm(:,1)-vppz))) 
  fprintf('  multi-col test: %.3g %.3g %.3g\n',max(abs(vcm(:,2)-0.5*vz)), max(abs(vcpm(:,2)-0.5*vpz)), max(abs(vcppm(:,2)-0.5*vppz))) 

  [A Ap App] = Cau_closeglobal(z,s,[],side);     % matrix fill case
  fprintf('  mat fill test: %.3g %.3g %.3g\n',max(abs(A*v(s.x)-vz)), max(abs(Ap*v(s.x)-vpz)), max(abs(App*v(s.x)-vppz)))

  % test N*N self matrix version
  [A Ap App] = Cau_closeglobal(s.x,s,[],side);   
  fprintf('  self-eval value ||A-I|| (should be 0):          %.3g\n', norm(A-eye(N)))  
  fprintf('  self-eval deriv mat apply err (tests S-W form): %.3g\n',max(abs(Ap*v(s.x)-vp(s.x))))
  fprintf('  self-eval deriv mat apply err (tests 2nd S-W form): %.3g\n',max(abs(App*v(s.x)-vpp(s.x))))
end

toc
%profile off; profile viewer    (uncomment to profile)
%figure; plot(s.x,'k.-'); hold on; plot(z,'+-'); axis equal




