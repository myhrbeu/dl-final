function z = apply_zscore(input, mu, sigma)

z = zeros(size(input));
for row_ind = 1:size(z,1)
    z(row_ind,:) = (input(row_ind,:)-mu)./sigma; %convert to zscore based on mu and sigma
end
end