function MATS = construct_model(t,x,PAR,u_trj,CON)

dim = size(x,1);
N = length(u_trj);
Nu = N - 1;
h = t(2) - t(1);
dim_u = size(u_trj,1);

%%%%%%%%%%%% CONSTRUCT A and B matrices %%%%%%%%%%%%%%%%%%%%%%%
A = zeros(dim,dim,N);
B = zeros(dim,dim_u,N);
for i = 1:N
    [~,A(:,:,i), B(:,:,i)] = robotTwoWheelsNominalKinematics(t(i),x(:,i),PAR,u_trj(:,i),true);
    % get discrete approximation from jacobian
    % crude approximation
    %A(:,:,i) = eye(dim,dim) + h * A(:,:,i);
    %B(:,i) = h * B(:,i);
    % exact matrix calculation 
    Mat = [A(:,:,i), B(:,:,i); zeros(dim_u, dim + dim_u)];
    MD = expm(h * Mat);
    A(:,:,i) = MD(1:dim,1:dim);
    B(:,:,i) = MD(1:dim,dim+1:end);
end

%%%%%%%%% CONSTRUCT lifted domain matrices F, G, and H %%%%%%%%
% G is identity matrix, H is zero matrix
F = zeros(N*dim, Nu*dim_u); % u is two-dimensional
G = eye(N*dim); % since y(t) = x(t) 
H = zeros(N*dim,Nu*dim_u); 
for l = 1:N
    for m = 1:Nu
        vec_x = (l-1)*dim + 1: l*dim;
        vec_u = (m-1)*dim_u + 1:m*dim_u;
        if m <= l
            MATS = eye(dim);
            for i = m+1:l
                MATS = MATS * A(:,:,i);
            end
            F(vec_x,vec_u) = MATS * B(:,:,m); % on diagonals only B(:,m)
        end
    end
end

% lifted domain constraints

%%%%%%%%%%%%%%%%%%%% CONSTRUCT umin and umax %%%%%%%%%%%%%
% extract constraints
x_cnstr = CON.x_cnstr;
y_cnstr = CON.y_cnstr;
w1_cnstr = CON.w1_cnstr;
w2_cnstr = CON.w2_cnstr;

u_shift = [u_trj(:,2:Nu), u_trj(:,Nu)];
umin(1,:) = -w1_cnstr - min([u_trj(1,1:Nu); u_shift(1,:)]);
umin(2,:) = -w2_cnstr - min([u_trj(2,1:Nu); u_shift(2,:)]);
umax(1,:) = w1_cnstr - max([u_trj(1,1:Nu); u_shift(1,:)]);
umax(2,:) = w2_cnstr - max([u_trj(2,1:Nu); u_shift(2,:)]);

% arrange them in a format suitable for optimization
umin = umin(:);
umax = umax(:);

%%%%%%%%%%%%%%%% CONSTRUCT x_con %%%%%%%%%%%%%%%%%%%

x_shift = [x(1,2:end), x(1,end)];
x_min = -x_cnstr - min([x(1,:); x_shift]);
x_max = x_cnstr - max([x(1,:); x_shift]);
y_shift = [x(2,2:end), x(2,end)];
y_min = -y_cnstr - min([x(2,:); y_shift]);
y_max = y_cnstr - max([x(2,:); y_shift]);

x_con_max = [x_max(:), y_max(:)];
x_con_max = x_con_max';
x_con_max = x_con_max(:);
x_con_min = [x_min(:), y_min(:)];
x_con_min = x_con_min';
x_con_min = x_con_min(:);
x_con = [x_con_max; -x_con_min];

% form the constraint matrix C
C = cell(1,N);
m = [1 0 0; 0 1 0];
[C{:}] = deal(m);
C = blkdiag(C{:});
C = [C; -C];

% return structure
MATS.F = F; 
MATS.G = G; 
MATS.H = H;
MATS.C = C; 
MATS.umin = umin; 
MATS.umax = umax; 
MATS.x_con = x_con;