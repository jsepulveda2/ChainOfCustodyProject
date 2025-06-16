"""
========================
ChainOfCustody_demo module
========================
@TaskDescription: This module provides a wrapper around web3.py API to interact with the EvidenceChainOfCustody smart contrac
"""
from web3 import Web3, HTTPProvider
import json
import datetime
import ipfshttpclient


class ChainOfCustody(object):
    def __init__(self, http_provider, contract_addr, contract_config, account):
        # configuration initialization
        self.web3 = Web3(HTTPProvider(http_provider))
        self.contract_address = Web3.to_checksum_address(contract_addr)
        self.contract_config = json.load(open(contract_config))
        self.account = Web3.to_checksum_address(account)

        # new contract object
        self.contract = self.web3.eth.contract(address=self.contract_address, abi=self.contract_config['abi'])

    # --- Blockchain info ---
    def getAccounts(self):
        return self.web3.eth.accounts

    def getBalance(self, account_addr = None):
        if account_addr is None:
            checksumAddr = self.account
        else:
            checksumAddr = Web3.to_checksum_address(account_addr)
        return self.web3.fromWei(self.web3.eth.get_balance(checksumAddr), 'ether')

    # --- Chain of Custody Functions ---
    def registerEvidence(self, caseId, evidenceId, holderName, description, ipfsHash, action="collected"):
        tx = self.contract.functions.registerEvidence(
            caseId, evidenceId, holderName, description, ipfsHash, action
        ).build_transaction({
            'from': self.account,
            'nonce': self.web3.eth.get_transaction_count(self.account)
        })
        signed_tx = self.web3.eth.account.sign_transaction(tx, private_key=self.getPrivateKey())
        tx_hash = self.web3.eth.send_raw_transaction(signed_tx.rawTransaction)
        return self.web3.eth.wait_for_transaction_receipt(tx_hash)

    def transferEvidence(self, caseId, evidenceId, to_addr, to_name, action="transferred", desc=""):
        tx = self.contract.functions.transferEvidence(
            caseId, evidenceId, Web3.to_checksum_address(to_addr), to_name, action, desc
        ).build_transaction({
            'from': self.account,
            'nonce': self.web3.eth.get_transaction_count(self.account)
        })
        signed_tx = self.web3.eth.account.sign_transaction(tx, private_key=self.getPrivateKey())
        tx_hash = self.web3.eth.send_raw_transaction(signed_tx.rawTransaction)
        return self.web3.eth.wait_for_transaction_receipt(tx_hash)

    def deleteEvidence(self, caseId, evidenceId):
        tx = self.contract.functions.deleteEvidence(
            caseId, evidenceId
        ).build_transaction({
            'from': self.account,
            'nonce': self.web3.eth.get_transaction_count(self.account)
        })
        signed_tx = self.web3.eth.account.sign_transaction(tx, private_key=self.getPrivateKey())
        tx_hash = self.web3.eth.send_raw_transaction(signed_tx.rawTransaction)
        return self.web3.eth.wait_for_transaction_receipt(tx_hash)

    def viewEvidence(self, caseId, evidenceId):
        return self.contract.functions.viewEvidence(caseId, evidenceId).call({'from': self.account})

    def getHistory(self, caseId, evidenceId):
        return self.contract.functions.getHistory(caseId, evidenceId).call({'from': self.account})

    # Fetch private keys securely
    def getPrivateKey(self):
        # For demo purposes, load from a local file, env var, or prompt
        with open("privatekey.txt") as f:
            return f.read().strip()

if __name__ == "__main__":
    # Load provider, contract address, ABI path, and your account (address & private key)
    with open('./addr_list.json') as f:
        addresses = json.load(f)
    httpProvider = addresses['HttpProvider']
    contractAddr = addresses['EvidenceChainOfCustody']
    userAccount = addresses['DemoUser']  # set this in addr_list.json
    contractConfig = './build/contracts/EvidenceChainOfCustody.json'

    # New instance
    coc = ChainOfCustody(httpProvider, contractAddr, contractConfig, userAccount)

    # Demo actions
    accounts = coc.getAccounts()
    print("Accounts:", accounts)
    print("Balance of user:", coc.getBalance(userAccount))

    # Register new evidence
    receipt = coc.registerEvidence("CASE555", "EV1", "Alice", "Demo USB drive", "QmIPFSHash001")
    print("Register receipt:", receipt)

    # View evidence
    evidence = coc.viewEvidence("CASE555", "EV1")
    print("Evidence data:", evidence)

    # Transfer evidence
    receipt = coc.transferEvidence("CASE555", "EV1", accounts[1], "Bob", "transferred", "For analysis")
    print("Transfer receipt:", receipt)

    # Get history
    hist = coc.getHistory("CASE555", "EV1")
    print("Evidence history:", hist)