import React from 'react';
export const AuctionCard = ({ auction }: any) => (
  <div className="card">
    <h3>Auction for Listing #{auction.listingId}</h3>
    <p>Reserve: {auction.reservePrice} STX</p>
    <p>Highest Bid: {auction.highestBid || "None"}</p>
    <button className="btn btn-primary">Place Bid</button>
  </div>
);
