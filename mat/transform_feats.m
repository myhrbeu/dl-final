function y = transform_feats(x,mu,sigma,db_rank,coeff,num_pcs)

% Convert x to z-score
z = zeros(size(x));
for row_ind = 1:size(z,1)
    z(row_ind,:) = (x(row_ind,:)-mu)./sigma; %convert to zscore based on mu and sigma
end

% Extract db-ranked features
z = z(:,db_rank);

% Transform to PCs
PCs = z*coeff;

% Extract important PCs
y = PCs(:,1:num_pcs);

end