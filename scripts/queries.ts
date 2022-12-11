import { request, gql } from 'graphql-request';
import { UNISWAPV3_GRAPH_ENDPOINT, USDC_MAINNET_ADDRESS } from '../constants';
import { IQueryUSDCPairsResult } from '../interfaces';

export const getUSDCTokenPairs = async (): Promise<IQueryUSDCPairsResult> => {
  const query = gql`
    query pairs($tokenId: String!) {
      usdcFirst: pools(first: 50, where: { token0: $tokenId }, orderBy: volumeUSD, orderDirection: desc) {
        id,
        token0 {
          id,
          name,
          symbol
        },
        token1 {
          id,
          name,
          symbol
        }
      },
      usdcSecond: pools(first: 50, where: { token1: $tokenId }, orderBy: volumeUSD, orderDirection: desc) {
        id,
        token0 {
          id,
          name,
          symbol
        },
        token1 {
          id,
          name,
          symbol
        }
      }
    }
  `;

  return request(UNISWAPV3_GRAPH_ENDPOINT, query, { tokenId: USDC_MAINNET_ADDRESS.toLowerCase() });
}