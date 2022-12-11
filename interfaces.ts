export interface TokenAddr {
  symbol: string;
  addr: string;
}

export interface ITokenDisplay {
  id: string,
  name: string,
  symbol: string,
};

export interface IPairDisplay {
  id: string;
  token0: ITokenDisplay,
  token1: ITokenDisplay,
};

export interface IQueryUSDCPairsResult {
  usdcFirst: Partial<IPairDisplay>[];
  usdcSecond: Partial<IPairDisplay>[];
}