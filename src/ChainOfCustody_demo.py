"""
========================
ChainOfCustody_demo module
========================
@TaskDescription: This module provides a wrapper around web3.py API to interact with 
the EvidenceChainOfCustody smart contract.
"""

from web3 import Web3, HTTPProvider
import json
import datetime
import warnings
warnings.filterwarnings("ignore", category=UserWarning, module="ipfshttpclient")

import ipfshttpclient

class ChainOfCustody(object):
	def __init__(self, http_provider, contract_addr, contract_config, account):
		# configuration initialization
		self.web3 = Web3(HTTPProvider(http_provider))
		self.contract_address = Web3.toChecksumAddress(contract_addr)
		self.contract_config = json.load(open(contract_config))
		self.account = Web3.toChecksumAddress(account)

		# new contract object
		self.contract = self.web3.eth.contract(
			address=self.contract_address, abi=self.contract_config['abi']
		)

	# --- Blockchain info ---
	def getAccounts(self):
		return self.web3.eth.accounts

	def getBalance(self, account_addr=None):
		if account_addr is None:
			checksumAddr = self.account
		else:
			checksumAddr = Web3.toChecksumAddress(account_addr)
		return self.web3.fromWei(self.web3.eth.get_balance(checksumAddr), 'ether')

	# --- Chain of Custody Functions ---
	def registerEvidence(self, caseId, evidenceId, holderName, description, ipfsHash, action="collected"):
		tx = self.contract.functions.registerEvidence(
			caseId, evidenceId, holderName, description, ipfsHash, action
		).transact({
			'from': self.account,
			'nonce': self.web3.eth.get_transaction_count(self.account)
		})
		return self.web3.eth.wait_for_transaction_receipt(tx)

	def transferEvidence(self, caseId, evidenceId, to_addr, to_name, action="transferred", desc=""):
		tx = self.contract.functions.transferEvidence(
			caseId, evidenceId, Web3.toChecksumAddress(to_addr), to_name, action, desc
		).transact({
			'from': self.account,
			'nonce': self.web3.eth.get_transaction_count(self.account)
		})
		return self.web3.eth.wait_for_transaction_receipt(tx)

	def deleteEvidence(self, caseId, evidenceId):
		tx = self.contract.functions.deleteEvidence(
			caseId, evidenceId
		).transact({
			'from': self.account,
			'nonce': self.web3.eth.get_transaction_count(self.account)
		})
		return self.web3.eth.wait_for_transaction_receipt(tx)

	def viewEvidence(self, caseId, evidenceId):
		return self.contract.functions.viewEvidence(caseId, evidenceId).call({'from': self.account})

	def getHistory(self, caseId, evidenceId):
		return self.contract.functions.getHistory(caseId, evidenceId).call({'from': self.account})

	# Fetch private keys securely
	def getPrivateKey(self):
		with open("privatekey.txt") as f:
			return f.read().strip()
	
	def getAllEvidenceIds(self):
		return self.contract.functions.getAllEvidenceIds().call({'from': self.account})

def upload_file_to_ipfs(filepath):
	try:
		client = ipfshttpclient.connect()
		res = client.add(filepath)
		print(f"File uploaded to IPFS with hash: {res['Hash']}")
		return res['Hash']
	except Exception as e:
		print(f"IPFS upload error: {e}")
		return None





def main_cli():
	

	# Load config and init contract wrapper here (adjust paths as needed)
	with open("addr_list.json") as f:
		config = json.load(f)
	HTTP_PROVIDER = config["HttpProvider"]
	CONTRACT_ADDRESS = config["EvidenceChainOfCustody"]
	CONTRACT_CONFIG_FILE = "../build/contracts/EvidenceChainOfCustody.json"
	USER_ACCOUNT = config["DemoUser"]
	ALT_ACCOUNT = config["AnotherUser"]

	coc = ChainOfCustody(HTTP_PROVIDER, CONTRACT_ADDRESS, CONTRACT_CONFIG_FILE, USER_ACCOUNT)

	def print_menu():
		print("\n==================")
		print("Chain of Custody Demo")
		print("====================")
		print("1. Register new evidence")
		print("2. Transfer evidence")
		print("3. Delete evidence")
		print("4. View evidence details")
		print("5. Get evidence history")
		print("6. List all evidence IDs")
		print("0. Exit")

	while True:
		print_menu()
		choice = input("Choose an option: ").strip()

		if choice == "1":
			caseId = input("Enter case ID: ")
			evidenceId = input("Enter evidence ID: ")
			holderName = input("Your holder name: ")
			description = input("Evidence description: ")
			filePath = input("Enter path to evidence file to upload: ")
			ipfsHash = upload_file_to_ipfs(filePath)

			if ipfsHash is None:
				print("Failed to upload file to IPFS. Cannot register evidence.")
			else:
				action = "collected"
				try:
					receipt = coc.registerEvidence(caseId, evidenceId, holderName, description, ipfsHash, action)
					print(f"Evidence registered with Tx Hash: {receipt.transactionHash.hex()}")
				except Exception as e:
					print(f"Error registering evidence: {e}")

		elif choice == "2":
			caseId = input("Enter case ID: ")
			evidenceId = input("Enter evidence ID: ")
			toAddress = input("Enter recipient Ethereum address: ")
			toName = input("Enter recipient name: ")
			action = "transferred"
			description = input("Transfer description: ")
			try:
				receipt = coc.transferEvidence(caseId, evidenceId, toAddress, toName, action, description)
				print(f"Evidence transferred with Tx Hash: {receipt.transactionHash.hex()}")
			except Exception as e:
				print(f"Error transferring evidence: {e}")

		elif choice == "3":
			caseId = input("Enter case ID: ")
			evidenceId = input("Enter evidence ID: ")
			try:
				receipt = coc.deleteEvidence(caseId, evidenceId)
				print(f"Evidence deleted with Tx Hash: {receipt.transactionHash.hex()}")
			except Exception as e:
				print(f"Error deleting evidence: {e}")

		elif choice == "4":
			caseId = input("Enter case ID: ")
			evidenceId = input("Enter evidence ID: ")
			try:
				e = coc.viewEvidence(caseId, evidenceId)
				print(f"\nEvidence ID: {e[0]}")
				print(f"Current Holder: {e[1]}")
				print(f"Holder Name: {e[2]}")
				print(f"Description: {e[3]}")
				print(f"IPFS Hash: {e[4]}")
				print(f"Deleted: {'Yes' if e[5] else 'No'}")
			except Exception as e:
				print(f"Error viewing evidence: {e}")

		elif choice == "5":
			caseId = input("Enter case ID: ")
			evidenceId = input("Enter evidence ID: ")
			try:
				history = coc.getHistory(caseId, evidenceId)
				if len(history) == 0:
					print("No history found.")
				else:
					for i, record in enumerate(history):
						timestamp = datetime.datetime.fromtimestamp(record[4]).strftime('%Y-%m-%d %H:%M:%S')
						print(f"\nEntry #{i+1}:")
						print(f"  Holder Address: {record[0]}")
						print(f"  Holder Name: {record[1]}")
						print(f"  Action: {record[2]}")
						print(f"  Description: {record[3]}")
						print(f"  Timestamp: {timestamp}")
			except Exception as e:
				print(f"Error fetching history: {e}")

		elif choice == "6":
			try:
				all_ids = coc.getAllEvidenceIds()
				print("\nAll evidence IDs:")
				for evid in all_ids:
					print(f" - {evid}")
			except Exception as e:
				print(f"Error listing evidence: {e}")

		elif choice == "0":
			print("Exiting CLI.")
			break

		else:
			print("Invalid choice. Please select a valid option.")

# Demo execution
if __name__ == "__main__":
	main_cli()

#if __name__ == "__main__":
	
	# # Register new evidence
	# print("\n Registering New Evidence...")
	# receipt = coc.registerEvidence(caseId, evidenceId, userAcc, evidenceDescription, "QpIPFSHash001")
	# print(f" Registered evidence. Tx Hash: {receipt.transactionHash.hex()} | Block #: {receipt.blockNumber}")

	# # View evidence
	# print("\n Viewing Registered Evidence:")
	# evidence = coc.viewEvidence(caseId, evidenceId)
	# print(f"  Evidence ID:       {evidence[0]}")
	# print(f"  Current Holder:    {evidence[1]}")
	# print(f"  Holder Name:       {evidence[2]}")
	# print(f"  Description:       {evidence[3]}")
	# print(f"  IPFS Hash:         {evidence[4]}")
	# print(f"  Deleted:           {'Yes' if evidence[5] else 'No'}")

	# # Transfer evidence
	# print("\n Transferring Evidence to Jim...")
	# receipt = coc.transferEvidence(caseId, evidenceId, ALT_ACCOUNT, altAcc, "transferred", transferDescription)
	# print(f" Evidence transferred. Tx Hash: {receipt.transactionHash.hex()} | Block #: {receipt.blockNumber}")

	# # Get history
	# print("\n Chain of Custody History:")
	# history = coc.getHistory(caseId, evidenceId)
	# for i, record in enumerate(history):
	# 	timestamp = datetime.datetime.fromtimestamp(record[4]).strftime('%Y-%m-%d %H:%M:%S')
	# 	print(f"\n  Entry #{i+1}")
	# 	print(f"    Holder Address: {record[0]}")
	# 	print(f"    Holder Name:    {record[1]}")
	# 	print(f"    Action:         {record[2]}")
	# 	print(f"    Description:    {record[3]}")
	# 	print(f"    Timestamp:      {timestamp}")


	# # Delete the evidence
	# print("\n Deleting Evidence Record...")
	# try:
	# 	receipt = coc.deleteEvidence(caseId, evidenceId)
	# 	print(f" Evidence deleted. Tx Hash: {receipt.transactionHash.hex()} | Block #: {receipt.blockNumber}")
	# except Exception as e:
	# 	print(f" Failed to delete evidence: {e}")

	# # Try viewing the deleted evidence again (should still return info, but marked deleted)
	# print("\n Viewing Deleted Evidence:")
	# try:
	# 	evidence = coc.viewEvidence(caseId, evidenceId)
	# 	print(f"  Evidence ID:       {evidence[0]}")
	# 	print(f"  Current Holder:    {evidence[1]}")
	# 	print(f"  Holder Name:       {evidence[2]}")
	# 	print(f"  Description:       {evidence[3]}")
	# 	print(f"  IPFS Hash:         {evidence[4]}")
	# 	print(f"  Deleted:           {'Yes' if evidence[5] else 'No'}")
	# except Exception as e:
	# 	print(f"  Could not view deleted evidence: {e}")




	# print("\n Full Chain of Custody Across All Evidence:")
	# evidence_ids = coc.getAllEvidenceIds()
	# if not evidence_ids:
	# 	print("  No evidence registered yet.")
	# else:
	# 	for evid in evidence_ids:
	# 		print(f"\nEvidence ID: {evid}")
	# 		try:
	# 			history = coc.getHistory(caseId, evid)  # Adjust caseId if dynamic
	# 			for i, record in enumerate(history):
	# 				timestamp = datetime.datetime.fromtimestamp(record[4]).strftime('%Y-%m-%d %H:%M:%S')
	# 				print(f"  - Entry #{i+1}")
	# 				print(f"    Holder Address: {record[0]}")
	# 				print(f"    Holder Name:    {record[1]}")
	# 				print(f"    Action:         {record[2]}")
	# 				print(f"    Description:    {record[3]}")
	# 				print(f"    Timestamp:      {timestamp}")
	# 		except Exception as e:
	# 			print(f"Could not fetch history: {e}")